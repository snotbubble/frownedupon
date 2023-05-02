// frownedupon
// org-compatible branchng script queue
// by c.p.brown 2023
//
//
// status: brain surgery (changed my mind about not using pointers)
//
// incompatibilities with org, so far...
// - no inline columnview (table from property drawers).
// - [[val:var]] link type is supported here (in paragraphs only), but not in org.
// - naming is independent of linking as it uses ids,
//   frownedupon will link stuff by name (or reference to name) on load, 
//   but after that you can link any output to any input, including property drawers,
//   which may not work with org-entry-get in org.
//   for now I'll assume the user knows this and will decide for themselves


using GLib;

// data.

struct output {
	uint id;
	int index;
	string name;
	string value;
	uint[] ibuff;
	element* owner;
	uint ebuff;
	input*[] targets;
}
struct input {
	uint id;
	int index;
	string name;
	string value;
	string defaultv;
	string org;
	element* owner;
	uint ebuff;
	uint obuff;
	output* source;
}
struct param {
	string type;					// source, language, flags, results, tangle, table, formula
	string name;
	uint id;
	string value;
}
struct element {
	string			name;			// can be whatever, but try to autoname to be unique
	uint			id;			// hash of name + iterator + time
	int			index;			// array index
	string			type;			// used for ui, writing back to org
	input*[]		inputs;		// can take input wires
	output*[]		outputs;		// can be wired out
	param[]		params;		// local params; no wiring
	uint[]			ibuff;			// input ids, for relinking after sorting and deletions
	uint[]			obuff;			// as above for outputs
	heading*		owner;			// the heading that owns this element
	uint			hbuff;			// id of heading, for relinking after sorting and deletion
}
struct todo {
	string			name;			// todo string, must be unique
	uint			id;			// hash of todo
	int			color;			// hex color for rendering
	uint[] 		headings;		// list of heading ids
}
struct priority {
	string			name;			// priority string, must be unique
	uint			id;			// hash of priority
	int			color;			// hex color for rendering
	uint[] 		headings;		// list of heading ids
}
struct tag {
	string			name;			// tag string, must be unique
	uint			id;			// hash of tag
	int			color;			// hex color for rendering
	uint[] 		headings;		// list of heading ids
}
// stuff that multiple headings use = their ids
// stuff that uses one heading..... = nested struct under heading
struct heading {
	string			name;			// can be whatever
	uint			id;			// hash of name + iterator + time
	int			index;			// array index
	int			stars;			// indentation
	uint			priority;		// id of priority, one per heading
	uint			todo;			// id of todo, one per heading
	uint[]			tags;			// id[] of tags, many per heading
	uint			template;		// internal use only: template id
	param[]		params;		// internal use only: fold, visible, positions 
	element*[]		elements;		// elements under this heading, might be broken out into flat lists later
	uint[]			ebuff;			// element ids for relinking after sorting and deletion
	string			nutsack;		// misc stuff found under the headigng that wasn't captured as elements 
}

// misc vars used everywhere

string[]		lines;			// the lines of an orgfile
string			srcblock;
string[]		hvars;			// header vars
string			headingname;
heading[]		headings;		// all headers for the orgfile
element[]		elements;
param[]		params;
input[]		inputs;
output[]		outputs;
int[]			typecount;		// used for naming: 0 paragraph, 1 propdrawer, 2 srcblock, 3, example, 4 table, 5 command, 6 nametag
bool			spew;			// print
bool			hard;			// print more
tag[]			tags;
priority[]		priorities;
todo[]			todos;
bool			doup;			// block ui events
uint			sel;			// selected item (fixed)
int			hidx;			// header list index of selected item (volatile)
int			eidx;			// element list index of selected item (volatile)
string[]		paneltypes;
ModalBox[]		modeboxes;
HeadingBox[]	headingboxes;

Gtk.Entry			saveentry;	// save file feeld
Gtk.Paned			vdiv;		// needed for reflow, resize, etc.
Gtk.CssProvider	butcsp;	// button css provider
string				butcss;	// button css string
Gtk.CssProvider	entcsp;	// entry css provider
string				entcss;	// entry css string
Gtk.CssProvider	lblcsp;	// label css provider
string				lblcss;	// label css string
Gtk.CssProvider	popcsp;	// popmenu css provider
string				popcss;	// popmenu css string


// default theme colors

string sbbkg;	// sb blue
string sbsel;
string sblin;
string sbhil;
string sblit;
string sbshd;
string sblow;
string sbent;

int imod (int a, int b) {
	if (a >= 0) { return (a % b); }
	if (a >= -b) { return (a + b); }
	return ((a % b) + b) % b;
}

void indexheadings () { for (int i = 0; i < headings.length; i++) { headings[i].index = i; } }
void indexelements () { for (int i = 0; i < elements.length; i++) { elements[i].index = i; } }
void indexinputs () { for (int i = 0; i < inputs.length; i++) { inputs[i].index = i; } }
void indexoutputs () { for (int i = 0; i < outputs.length; i++) { outputs[i].index = i; } }

void elementownsio (int e) {
	for(int w = 0; w < elements[e].outputs.length; w++) {
		elements[e].outputs[w].owner = &elements[e];
	}
	for(int w = 0; w < elements[e].inputs.length; w++) {
		elements[e].inputs[w].owner = &elements[e];
	}
}

int getmysourceindexbyname (string n) {
	for (int o = 0; o < outputs.length; o++) {
		if (outputs[o].name == n) { return o; }
	}
	return -1;
}

void deletemyinputs(uint[] d) {
// removes all io linkage, keeps all id buffers except whatever is in the delete list
// rebuilds io linkage using id buffers
	int64 dints = GLib.get_real_time();

// clear io links, removing input ids from buffers
	for (int i = 0; i < inputs.length; i++) {
		if (inputs[i].source != null) {
			inputs[i].source = null;
		}
	}
	for (int o = 0; o < outputs.length; o++) {
		outputs[o].targets = {};
		uint[] tb = {};
		for (int b = 0 ; b < outputs[o].ibuff.length; b++) {
			if ((outputs[o].ibuff[b] in d) == false) {
				if ((outputs[o].ibuff[b] in tb) == false) {
					tb += outputs[o].ibuff[b];
				}
			}
		}
		outputs[o].ibuff = tb;
	}
	for (int n = 0; n < elements.length; n++) {
		elements[n].inputs = {};
		elements[n].outputs = {};
		uint[] tb = {};
		for (int b = 0 ; b < elements[n].ibuff.length; b++) {
			if ((elements[n].ibuff[b] in d) == false) {
				if ((elements[n].ibuff[b] in tb) == false) {
					tb += elements[n].ibuff[b];
				}
			}
		}
		elements[n].ibuff = tb; 
	}

// delete inputs
	input[] k = {};
	for (int i = 0; i < inputs.length; i++) {
		if ((inputs[i].id in d) == false) { k += inputs[i]; }
	}
	inputs = k;

// re-link io
	for (int i = 0; i < inputs.length; i++) {
		if (inputs[i].obuff > 0) {
			for (int q = 0; q < outputs.length; q++) {
				if (outputs[q].id == inputs[i].obuff) {
					inputs[i].source = &outputs[q]; break;
				}
			}
		}
	}
	for (int o = 0; o < outputs.length; o++) {
		if (outputs[o].ibuff.length > 0) {
			for (int t = 0; t < outputs[o].ibuff.length; t++) {
				for (int q = 0; q < inputs.length; q++) {
					if (inputs[q].id == outputs[o].ibuff[t]) {
						outputs[o].targets += &inputs[q];
					}
				}
			}
		}
	}

// re-link element io
	for (int n = 0; n < elements.length; n++) {
		for(int i = 0; i < elements[n].ibuff.length; i++) { 
			for (int q = 0; q < inputs.length; q++) {
				if (inputs[q].id == elements[n].ibuff[i]) {
					elements[n].inputs += &inputs[q];
				}
			}
		}
		for(int i = 0; i < elements[n].obuff.length; i++) { 
			for (int q = 0; q < outputs.length; q++) {
				if (outputs[q].id == elements[n].obuff[i]) {
					elements[n].outputs += &outputs[q];
				}
			}
		}
	}

	indexinputs();
	int64 dinte = GLib.get_real_time();
	if (spew) { print("\ndelete inputs took %f microseconds\n",((double) (dinte - dints))); }
}

int getelementindexbyid(uint n) {
	for (int q = 0; q < elements.length; q++) {
		if (n == elements[q].id) { return q; }
	}
	return -1;
}

int getinputindexbyid(uint n) {
	for (int q = 0; q < inputs.length; q++) {
		if (n == inputs[q].id) { return q; }
	}
	return -1;
}

int getoutputindexbyid(uint n) {
	for (int q = 0; q < outputs.length; q++) {
		if (n == outputs[q].id) { return q; }
	}
	return -1;
}

int[] getmysourcepathbyid (uint n) {
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int o = 0; o < headings[h].elements[e].outputs.length; o++) {
				if (headings[h].elements[e].outputs[o].id == n) { 
					if (headings[h].elements[e].outputs[o].id != 0) {
						return {h,e,o};
					}
				}
			}
		}
	}
	return {0};
}

int[] getmysourcepathbyname (string n) {
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int o = 0; o < headings[h].elements[e].outputs.length; o++) {
				if (headings[h].elements[e].outputs[o].name == n) { 
					return {h,e,o};
				}
			}
		}
	}
	return {0};
}

string getheadingnamebyid (uint n) {
	for (int h = 0; h < headings.length; h++) {
		if (headings[h].id == n) { 
			if (headings[h].name != null) { return headings[h].name; }
		}
	}
	return "";
}

int getheadingindexbyid (uint n) {
	for (int h = 0; h < headings.length; h++) {
		if (headings[h].id == n) { return h; }
	}
	return -1;
}

int getmysourceindexbypropname(string n, int g, int y) {
	if (spew) { print("\t\tgetmysourceindexbypropname started...\n"); }
	for (int h = g; h >= 0; h--) {
		if (spew) { print("\t\t\tgetmysourceindexbypropname checking heading[%d] %s...\n",h,headings[h].name); }
		if (headings[h].stars <= y) {
			for (int e = 0; e < headings[h].ebuff.length; e++) {
				if (spew) { print("\t\t\t\tgetmysourceindexbypropname checking heading[%d].elements[%d] %s...\n",h,e,headings[h].elements[e].name); }
				for (int o = 0; o < headings[h].elements[e].obuff.length; o++) {
					if (spew) { print("\t\t\t\t\tgetmysourceindexbypropname checking heading[%d].elements[%d].outputs[%d] %s...\n",h,e,o,headings[h].elements[e].outputs[o].name); }
					if (headings[h].elements[e].outputs[o].name == n) { 
						if (spew) { print("\t\tgetmysourceindexbypropname returned %d\n",headings[h].elements[e].outputs[o].index); }
						return headings[h].elements[e].outputs[o].index; 
					}
				}
			}
		} else { break; }
	}
	if (spew) { print("\t\tgetmysourceindexbypropname found nothing.\n"); }
	return -1;
}

int getmysourcebyvalvar(string n, int g, int y) {
	for (int h = g; h >= 0; h--) {
		if (headings[h].stars <= y) {
			for (int e = 0; e < headings[h].elements.length; e++) {
				for (int o = 0; o < headings[h].elements[e].outputs.length; o++) {
					if (headings[h].elements[e].outputs[o].name == n) { 
						return headings[h].elements[e].outputs[o].index; 
					}
				}
			}
		} else { break; }
	}
	return getmysourceindexbyname(n);
}

// initial linking using orgmode rules:
// reverse local search for propertydrawer vars, stopping at 1-star heading
// then global search for name from the 1st heading
//
// for non-orgmode [[val:var]] links the search is the same as propertydrawer vars, then global
void buildpath () {
	int e = -1;
	int o = -1;
	int i = -1;
	for (int h = 0; h < headings.length; h++) {
		headings[h].elements = {};
		for (int b = 0; b < headings[h].ebuff.length; b++) {
			e = getelementindexbyid(headings[h].ebuff[b]);
			if (e >= 0) {
				elements[e].inputs = {};
				elements[e].outputs = {};
				headings[h].elements += &elements[e];
				elements[e].hbuff = headings[h].id;
				elements[e].owner = &headings[h];
				for (int c = 0; c < elements[e].ibuff.length; c ++) {
					i = getinputindexbyid(elements[e].ibuff[c]);
					if (i >= 0) {
						elements[e].inputs += &inputs[i];
						inputs[i].owner = &elements[e];
						inputs[i].ebuff = elements[e].id;
					}
				}
				for (int d = 0; d < elements[e].obuff.length; d ++) {
					o = getoutputindexbyid(elements[e].obuff[d]);
					if (o >= 0) {
						elements[e].outputs += &outputs[o];
						outputs[o].owner = &elements[e];
						outputs[o].ebuff = elements[e].id;
					}
				}
			}
		}
	}
}

void crosslinkio () {
	uint myo = 0;
	int e = -1;
	int o = -1;
	int i = -1;
	for (int h = 0; h < headings.length; h++) {
		for (int b = 0; b < headings[h].ebuff.length; b++) {
			e = getelementindexbyid(headings[h].ebuff[b]);
			if (e >= 0) {
				for (int c = 0; c < elements[e].ibuff.length; c ++) {
					i = getinputindexbyid(elements[e].ibuff[c]);
					if (i >= 0) {
						if (inputs[i].name != null && inputs[i].name != "") {
							if (inputs[i].org != null && inputs[i].org != "") {
								if (inputs[i].org.contains("org-entry-get")) {
// local search for propbin
									int sq = inputs[i].org.index_of("\"") + 1;
									int eq = inputs[i].org.last_index_of("\"");
									if (eq > sq) {
										myo = getmysourceindexbypropname(inputs[i].org.substring(sq,(eq-sq)),h,headings[h].stars);
									}
								}
								if (inputs[i].org.contains("[[val:")) {

// local search for name or propbin. failing that: global name search
									int sq = inputs[i].org.index_of(":") + 1;
									int eq = inputs[i].org.last_index_of("]]");
									myo = getmysourcebyvalvar(inputs[i].org.substring(sq,(eq-sq)),h,headings[h].stars);
								}
							} else {

// global search for matching nametag name for inputs extracted from scrblock :var strings
								myo = getmysourceindexbyname(inputs[i].name);
							}
							if (myo >= 0) { inputs[i].source = &outputs[myo]; }
						}
					}
				}
			}
		}
	}
	for (int q = 0; q < outputs.length; q++) {
		outputs[q].targets = {};
		outputs[q].ibuff = {};
	}
	for (int j = 0; j < inputs.length; j++) {
		if (inputs[j].source != null) {
			inputs[j].source.targets += &inputs[j];
			inputs[j].source.ibuff += inputs[j].id;
			inputs[j].obuff = inputs[j].source.id;
		}
	}
}

void oldcrosslinkeverything () {
	uint myo = 0;
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int i = 0; i < headings[h].elements[e].inputs.length; i++) {
				myo = 0;
				if (headings[h].elements[e].inputs[i].name != null) { 
					if (headings[h].elements[e].inputs[i].name != "") { 
						if (headings[h].elements[e].inputs[i].org != null && headings[h].elements[e].inputs[i].org != "") {
							if (spew) { print("\tcrosscheck: checking input %s org: %s\n",headings[h].elements[e].inputs[i].name, headings[h].elements[e].inputs[i].org); }
							if (headings[h].elements[e].inputs[i].org.contains("org-entry-get")) {

// local search for propbin
								int sq = headings[h].elements[e].inputs[i].org.index_of("\"") + 1;
								int eq = headings[h].elements[e].inputs[i].org.last_index_of("\"");
								if (eq > sq) {
									myo = getmysourceindexbypropname(headings[h].elements[e].inputs[i].org.substring(sq,(eq-sq)),h,headings[h].stars);
								}
							}
							if (headings[h].elements[e].inputs[i].org.contains("[[val:")) {

// local search for name or propbin. failing that: global name search
								int sq = headings[h].elements[e].inputs[i].org.index_of(":") + 1;
								int eq = headings[h].elements[e].inputs[i].org.last_index_of("]]");
								myo = getmysourcebyvalvar(headings[h].elements[e].inputs[i].org.substring(sq,(eq-sq)),h,headings[h].stars);
							}
						} else {
							myo = headings[h].elements[e].inputs[i].source.index;
						}
						if (myo != 0) { headings[h].elements[e].inputs[i].source = &outputs[myo]; }
					}
				}
			}
		}
	}
	for (int i = 0; i < inputs.length; i++) {
		if (inputs[i].source != null) {
			inputs[i].source.targets += &inputs[i];
			inputs[i].source.ibuff += inputs[i].id;
			inputs[i].obuff = inputs[i].source.id;
		}
	}
}



int findtodoindexbyname (string n, todo[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

uint findtodoidbyname (string n, todo[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return h[q].id; }
	}
	return -1;
}

uint findpriorityidbyname (string n, priority[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return h[q].id; }
	}
	return -1;
}

int findpriorityindexbyname (string n, priority[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

int findtagindexbyname (string n, tag[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

string findtagnamebyid (uint t, tag[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].id == t) { return h[q].name; }
	}
	return "";
}


uint findtagidbyname (string n, tag[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return h[q].id; }
	}
	return -1;
}

bool notininputnames (string n) {
	for (int q = 0; q < inputs.length; q++) {
		if (inputs[q].name == n) { return false; }
	}
	return true;
}

bool notinuint(uint n, uint[] h) {
	for (int q = 0; q < h.length; q++) {
		if (n == h[q]) { return true; }
	}
	return false;
}

bool notintagnames (string n, tag[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return false; }
	}
	return true;
}

bool notinprioritynames (string n, priority[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return false; }
	}
	return true;
}

bool notintodonames (string n, todo[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return false; }
	}
	return true;
}

uint[] removeidfromtags(uint t, uint[] a) {
	uint[] tmp = new uint[(a.length - 1)];
	for (int j = 0; j < a.length; j++) {
		if (a[j] == t) { 
			for (int i = 0; i < a.length; i++) {
				if (a[i] != t) {
					tmp += a[i];
					if (tmp.length == (a.length - 1)) { return tmp; }
				}
			}
			return tmp;
		}
	}
	uint[] o = {};
	return o;
}

void toggleheadertagbyindex(int h, uint t) {
	if ((t in headings[h].tags) == false) {
		headings[h].tags += t;
	} else {
		headings[h].tags = removeidfromtags(t,headings[h].tags);
	}
}

int getparamindexbyid(int e, uint x) {
	if (spew) { print("getparamindexbyid(%d,%u)",e,x); }
	for(int p = 0; p < elements[e].params.length; p++){
		if (elements[e].params[p].id == x) { return p; }
	}
	return -1;
}

void addheadertotagsbyindex (int i, int h) {
	for (int g = 0; g < tags.length; g++) {
		uint[] tmp = {};
		if ((tags[g].id in headings[h].tags) == false) {
			for (int d = 0; d < tags[g].headings.length; d++) {
				if (tags[g].headings[d] != headings[h].id) {
					tmp += tags[g].headings[d];
				}
			}
			tags[g].headings = tmp;
		}
	}
	tags[i].headings += headings[h].id;
}

void addheadertoprioritiesbyindex (int i, uint x) {
	for (int p = 0; p < priorities.length; p++) {
		uint[] tmp = {};
		for (int h = 0; h < priorities[p].headings.length; h++) {
			if (priorities[p].headings[h] != x) {
				tmp += priorities[p].headings[h];
			}
		}
		if (priorities[p].headings.length != tmp.length) {
			priorities[p].headings = tmp;
			//for (int h = 0; h < priorities[p].headings.length; h++) {
			//}
		}
	}
	priorities[i].headings += x;
}

void addheadertotodosbyindex (int i, uint x) {
	//print("todo array index: %d, header id: %u, todo.length: %d\n",i,x,todos.length);
	for (int t = 0; t < todos.length; t++) {
		//print("\tchecking todo[%d]: %s\n",t,todos[t].name);
		uint[] tmp = {};
		for (int h = 0; h < todos[t].headings.length; h++) {
			//print("\t\tchecking todo[%d].headings[%d]: %u == %u\n",t,h,todos[t].headings[h],x);
			if (todos[t].headings[h] != x) {
				tmp += todos[t].headings[h];
			}
		}
		if (todos[t].headings.length != tmp.length) {
			todos[t].headings = tmp;
			//for (int h = 0; h < todos[t].headings.length; h++) {
				//print("\t\tchecking todo[%d].headings[%d]: %u == %u\n",t,h,todos[t].headings[h],x);
			//}
		}
	}
	todos[i].headings += x;
}

// TODO: check for conflicts
uint makemeahash(string n, int t) {
	return "%s_%d_%lld".printf(n,t,GLib.get_real_time()).hash();
}

string makemeauniqueoutputname(string n) {
	int64 uqts = GLib.get_real_time();
	string k = n;
	string j = n;
	if (n.strip() == "") { k = "untitled_output"; j = k; }
	string[] shorts = {};
	for (int o = 0; o < outputs.length; o++) {
		if (outputs[o].name != null) {
			if (outputs[o].name.length > 0) {
				if (outputs[o].name[0] == n[0]) {
					shorts += outputs[o].name;
				}
			}
		}
	}
	int x = 1;
	if (shorts.length > 0) {
		int maxout = (shorts.length * shorts.length);
		while ((k in shorts) == true) {
			int ld = (k.length - 1); while (ld > 0 && k[ld].isdigit()) { ld--; }
			string digs = k.substring((ld + 1),(k.length - (ld + 1)));
			k = "%s%d".printf(j.substring(0,(ld + 1)),(int.parse(digs) + 1));
			x += 1;
			if (x > maxout) { break; } // incasement
		}
	}
	int64 uqte = GLib.get_real_time();
	if (spew) {
		print("\nuniqueoutputname took %f micorseconds @%d rounds and returned: %s\n\n",((double) (uqte - uqts)),x,k); 
	}
	return k;
}

string makemeauniqueelementname(string n, uint u, string y) {
	int64 uqts = GLib.get_real_time();
	string k = n;
	string j = n;
	if (n.strip() == "") { k = "untitled_%s".printf(y); j = k; }
	string[] shorts = {};
	for (int e = 0; e < elements.length; e++) {
		if (elements[e].id != u) {
			if (elements[e].type != null) {
				if (elements[e].type == y) {
					if (elements[e].name != null) {
						if (elements[e].name.length > 0) {
							if (elements[e].name[0] == n[0]) {
								shorts += elements[e].name;
							}
						}
					}
				}
			}
		}
	}
	int x = 1;
	if (shorts.length > 0) {
		int maxout = (shorts.length * shorts.length);
		while ((k in shorts) == true) {
			int ld = (k.length - 1); while (ld > 0 && k[ld].isdigit()) { ld--; }
			string digs = k.substring((ld + 1),(k.length - (ld + 1)));
			k = "%s%d".printf(j.substring(0,(ld + 1)),(int.parse(digs) + 1));
			x += 1;
			if (x > maxout) { break; } // incasement
		}
	}
		int64 uqte = GLib.get_real_time();
	if (spew) {
		print("\nuniqueelementname took %f micorseconds @%d rounds and returned: %s\n\n",((double) (uqte - uqts)),x,k); 
	}
	return k;
}

string renameuniqueoutputname(string n, uint u, string y) {
	int64 uqts = GLib.get_real_time();
	string k = n;
	string j = n;
	if (n.strip() == "") { k = "%s_output".printf(y); j = k; }
	string[] shorts = {};
	for (int o = 0; o < outputs.length; o++) {
		if (outputs[o].owner.type != null) {
			if (outputs[o].owner.type == y) {
				if (outputs[o].id != u) {
					if (outputs[o].name != null) {
						if (outputs[o].name.length > 0) {
							if (outputs[o].name[0] == n[0]) {
								shorts += outputs[o].name;
							}
						}
					}
				}
			}
		}
	}
	int x = 1;
	if (shorts.length > 0) {
		int maxout = (shorts.length * shorts.length);
		while ((k in shorts) == true) {
			int ld = (k.length - 1); while (ld > 0 && k[ld].isdigit()) { ld--; }
			string digs = k.substring((ld + 1),(k.length - (ld + 1)));
			k = "%s%d".printf(j.substring(0,(ld + 1)),(int.parse(digs) + 1));
			x += 1;
			if (x > maxout) { break; } // incasement
		}
	}
	int64 uqte = GLib.get_real_time();
	if (spew) {
		print("\nuniqueoutputname took %f micorseconds @%d rounds and returned: %s\n\n",((double) (uqte - uqts)),x,k); 
	}
	return k;
}

bool updatevalvarlinks(string t, int h, int e) {
	bool oo = false;
	if (spew) { print("updatevalvarlinks: string =\n%s\n",t); }
	deletemyinputs(elements[e].ibuff);
	if (t.contains("[[val:") && t.contains("]]")) {
		string chmpme = t;
		int safeteycheck = 100;
		while (chmpme.contains("[[val:") && chmpme.contains("]]")) {
			int iidx = chmpme.index_of("[[val:");
			int oidx = chmpme.index_of("]]") + 2;
			if (spew) { print("updatevalvarlinks: link start index is %d, end offset is %d\n",iidx,(oidx - iidx)); }
			if (oidx > iidx) { 
				string chmp = chmpme.substring(iidx,(oidx - iidx));
				if (spew) { print("updatevalvarlinks: extracted link is %s\n",chmp); }
				if (chmp != null && chmp != "") {
					string ct = chmp.replace("]]","");
					string[] cn = ct.split(":");
					if (cn.length == 2) {
						if (spew) { print("updatevalvarlinks: checking for %s in inputs\n",cn[1]); }
						input qq = input();
						qq.org = chmp;
						qq.defaultv = chmp;
						qq.name = cn[1];
						qq.id = makemeahash(qq.name,(elements[e].inputs.length + 1));
						inputs += qq;
						elements[e].inputs += &inputs[(inputs.length - 1)];
						inputs[(inputs.length - 1)].source = &outputs[(getmysourceindexbyname(cn[1]))];
						inputs[(inputs.length - 1)].obuff = inputs[(inputs.length - 1)].source.id;
						inputs[(inputs.length - 1)].owner = &elements[e];
						inputs[(inputs.length - 1)].ebuff = elements[e].id;
						elements[e].ibuff += qq.id;
						elementownsio(e);
						chmpme = chmpme.replace(chmp,"");
						oo = true;
					}
					if (safeteycheck > 1000) { break; }
				}
			}
			safeteycheck += 1;
		}
	} else { return false; }
	return oo;
}

int[] evalpath (int[] nn, int me) {
	int r = 0;
	int[] ss = nn;
	int[] ee = {};
	ee += me;
	ee += inputs[ss[0]].owner.index;
	while (r < ss.length) {
		print("evalpath: finding sources of %s\n",inputs[r].name);
		if (inputs[r].source != null) {
			print("evalpath:\tfound source: %s\n",inputs[r].source.name);
			ee += inputs[r].source.owner.index;
			for(int i = 0; i < inputs[r].source.owner.inputs.length; i++) {
				ss += inputs[r].source.owner.inputs[i].index;
			}
		}
		r += 1;
		if (r > 100) { break; }
	}
	int[] te = {};
	for (int j = (ee.length - 1); j > 0; j--) { 
		if ((ee[j] in te) == false) { te += ee[j]; }
		print("te[%d] = %s\n",(te.length - 1),elements[(te[(te.length - 1)])].name);
	}
	return te;
}


int gettodobyid(uint t) {
	for (int i = 0; i < todos.length; i++) {
		if (todos[i].id == t) {
			return i;
		}
	}
	return todos.length;
}

int getpribyid(uint t) {
	for (int i = 0; i < priorities.length; i++) {
		if (priorities[i].id == t) {
			return i;
		}
	}
	return priorities.length;
}
string gettags (uint[] t) {
	string s = "";
	int tc = 0;
	for (int i = 0; i < t.length; i++) {
		for (int p = 0; p < tags.length; p++) {
			if (tags[p].id == t[i]) {
				if (tc == 0) {
					s = s.concat(" :", tags[p].name, ":");
				} else {
					s = s.concat(tags[p].name, ":");
				}
				tc += 1;
			}
		}
	}
	return s;
}

void printheadings (int ind) {
	int64 prtts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("%sprintheadings started...\n",tabs); }
	string s = "**********";
	string t = "";
	string p = "";
	string g = "";
	for (int i = 0; i < headings.length; i++) {
		t = "";
		p = "";
		g = "";
		int tidx = gettodobyid(headings[i].todo);
		if (tidx < todos.length) { t = "%s ".printf(todos[tidx].name); }
		int pidx = getpribyid(headings[i].priority);
		if (pidx < priorities.length) { p = "%s ".printf(priorities[pidx].name); }
		if (headings[i].tags.length > 0) {
			g = gettags(headings[i].tags);
		}
		print("%.*s %s%s%s%s\n",headings[i].stars,s,t,p,headings[i].name,g);
	}
}

// org parsing, super tedious but has to be accurate

int findexample (int l, int ind, string n) {
	int64 xtts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindexample started...\n",l,tabs); }
	string txtname = "";
	if (n == "") { txtname =  "example_%d".printf(typecount[3]); }  // examples can be named
	string[] txt = {};
	bool amexample = false;
	int c = 0;
	if (lines[l].strip().has_prefix("#+BEGIN_EXAMPLE")) {
		for (c = (l + 1); c < lines.length; c++) {
			string cs = lines[c].strip();
			if (cs.has_prefix("#+END_EXAMPLE")) { break; }
			if (spew) { print("[%d]%s\t verbatim text: %s\n",c,tabs,lines[c]); }
			txt += lines[c];
		}
		if (txt.length > 0) {
			if (spew) { print("[%d]%s\tverbatim was collected, checking it...\n",c,tabs); }
			if (n != "") { txtname = n; }
			element ee = element();
			ee.name = txtname;
			ee.type = "example";
			ee.id = makemeahash(ee.name,c);
			output pp = output();
			pp.name = makemeauniqueoutputname(ee.name.concat("_verbatimtext"));
			pp.id = makemeahash(ee.name, c);
			pp.value = string.joinv("\n",txt);
			pp.ebuff = ee.id;
			outputs += pp;
			ee.outputs += &outputs[(outputs.length - 1)];
			ee.obuff += pp.id;
			typecount[3] += 1;
			ee.owner = &headings[hidx];
			ee.hbuff = headings[hidx].id;
			elements += ee;
			headings[hidx].elements += &elements[(elements.length - 1)];
			headings[hidx].ebuff += ee.id;
			elementownsio((elements.length - 1));
			if (spew) { print("[%d]%s\tsuccessfully captured verbatim text\n",c,tabs); }
			if (spew) { print("[%d]%sfindexample ended.\n",c,tabs); }
			int64 xtte = GLib.get_real_time();
			if (spew) { print("\nfind example took %f microseconds\n\n",((double) (xtte - xtts)));}
			return (c + 1);
		}
	}
	if (spew) { print("[%d]%sfindexample found nothing.\n",l,tabs); }
	int64 xtte = GLib.get_real_time();
	if (spew) { print("\nfind example took %f microseconds\n\n",((double) (xtte - xtts)));}
	return l;
}

int findparagraph (int l, int ind) {
	int64 phtts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindparagraph started...\n",l,tabs); }
	if (spew) { print("[%d]%sheadings[%d].name = %s\n",l,tabs,hidx,headings[hidx].name); }
	if (spew) { print("[%d]%sheadings[%d].id = %u\n",l,tabs,hidx,headings[hidx].id); }
	string txtname = "paragraph_%d".printf(typecount[0]);
	//if (n == "") { txtname =  "srcblock_%d".printf(typecount[2]); }  // don't NAME paragraphs
	string[] txt = {};
	int c = 0;
	for (c = l; c < lines.length; c++) {
		string cs = lines[c].strip();
		if (cs.has_prefix("*")) { break; }
		if (cs.has_prefix("#+")) { break; }
		if (cs.has_prefix(";#+")) { break; }
		if (cs.has_prefix("# -*-")) { break; }
		if (cs.has_prefix("#-*-")) { break; }
		if (cs.has_prefix(": ")) { break; }
		if (cs.has_prefix(":PROPERTIES:") || cs.has_prefix(":END:")) { break; }
		if (spew) { print("[%d]%s\t plain text: %s\n",c,tabs,lines[c]); }
		txt += lines[c];
	}
	if (txt.length > 0) {
		if (spew) { print("[%d]%s\ttext was collected, checking it...\n",c,tabs); }
		string txtval = string.joinv("\n",txt);
		if (txtval.strip() != "") {
			element ee = element();
			ee.name = txtname;
			ee.id = makemeahash(ee.name,c);
			ee.type = "paragraph";
			output pp = output();
			//pp.target = null;
			pp.name = makemeauniqueoutputname(ee.name.concat("_text"));
			pp.id = makemeahash(ee.name, c);
			pp.value = string.joinv("\n",txt);
			pp.ebuff = ee.id;
			outputs += pp;
			ee.outputs += &outputs[(outputs.length - 1)];
			ee.obuff += pp.id;
			for (int d = 0; d < txt.length; d++) {
	// minum text size for a [[val:v]] link
				if (txt[d].length > 9) { 
					if (spew) { print("[%d]%s\t\tlooking for val:var links in text: %s\n",c,tabs,txt[d]); }
					if (txt[d].contains("[[val:") && txt[d].contains("]]")) {
						if (spew) { print("[%d]%s\t\t\ttxt[%d] has a link: %s\n",c,tabs,d,txt[d]); }
	// ok now for the dumb part:
						string chmpme = txt[d];
						int safeteycheck = 100;
						while (chmpme.contains("[[val:") && chmpme.contains("]]")) {
							if (spew) { print("[%d]%s\t\t\tchmpme still has a link: %s\n",c,tabs,chmpme); }
							int iidx = chmpme.index_of("[[val:");
							int oidx = chmpme.index_of("]]") + 2;
							if (oidx > iidx) { 
								string chmp = txt[d].substring(iidx,(oidx - iidx));
								if (chmp != null && chmp != "") {
									if (spew) { print("[%d]%s\t\t\textracted link: %s\n",c,tabs,chmp); }
									input qq = input();
									//qq.source = null;
									qq.org = chmp;
									qq.defaultv = chmp;
									chmpme = chmpme.replace(chmp,"");
									chmp = chmp.replace("]]","");
									qq.name = chmp.split(":")[1];
									qq.id = makemeahash(qq.name,c);
									qq.ebuff = ee.id;
									inputs += qq;
									ee.inputs += &inputs[(inputs.length)];
									ee.ibuff += qq.id;
									if (spew) { print("[%d]%s\t\t\tstored link ref: %s\n",c,tabs,qq.name); }
		// suckshit if there's over 100 links in a paragraph
									if (safeteycheck > 100) { break; }
								}
							}
							safeteycheck += 1;
						}
					}
				}
			}
			if (spew) { print("[%d]%s\tcapturing owner id: %u\n",c,tabs,headings[hidx].id); }
			ee.hbuff = headings[hidx].id;
			ee.owner = &headings[hidx];
			if (spew) { print("[%d]%s\tcapturing element: %s\n",c,tabs,ee.name); }
			elements += ee;
			headings[hidx].elements += &elements[(elements.length - 1)];
			headings[hidx].ebuff += ee.id;
			elementownsio((elements.length - 1));
			typecount[0] += 1;
			if (spew) { print("[%d]%s\tsuccessfully captured plain text\n",c,tabs); }
			if (spew) { print("[%d]%sfindparagraph ended.\n",c,tabs); }
			int64 phtte = GLib.get_real_time();
			if (spew) { print("\nfind paragraph took %f microseconds\n\n",((double) (phtte - phtts)));}
			return c;
		} else { 
			if (spew) { print("[%d]%sfindparagraph captured empty text, skipping it.\n",l,tabs); }
		}
	}
	if (spew) { print("[%d]%sfindparagraph found nothing.\n",l,tabs); }
	int64 phtte = GLib.get_real_time();
	if (spew) { print("\nfind paragraph took %f microseconds\n\n",((double) (phtte - phtts)));}
	return l;
}

int findtable (int l, int ind, string n) {
	int64 ttts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	bool dospew = spew;
	if (dospew) { print("[%d]%sfindtable started...\n",l,tabs); }
	string tablename = "";
	if (n == "") { tablename =  "table_%d".printf(typecount[4]); }   // can NAME tables
	string ls = lines[l].strip();
	if (ls.has_prefix("#+BEGIN_TABLE")) {
		if (dospew) { print("[%d]%s\tfindtable found table header: %s\n",l,tabs,ls); }
		int t = (l + 1);
		int rc = 0;
		int cc = 0;
		int tln = 0;
		string[] lsp = {};
		ls = lines[t].strip();

// skip blanks
		while (ls == "") {
			if (t == lines.length) { break; } 
			t += 1; 
			ls = lines[t].strip(); 
		}

// get column count
		if (dospew) { print("[%d]%s\t\tfindtable looking for table in: %s\n",l,tabs,ls); }
		if (ls.has_prefix("|")) {
			lsp = ls.split("|");
			if (lsp[(lsp.length - 1)].strip() == "") {
				cc = (lsp.length - 2);
				tln = t;
			}
		}
		if (cc > 0) {
			if (dospew) { print("[%d]%s\t\tfindtable counted %d columns\n",l,tabs,cc); }
			bool amtable = false;
			for (t = (l + 1); t < lines.length; t++) {
				ls = lines[t].strip();
				if (amtable && ls == "") { break; }
				if (amtable == false && ls == "") { continue; }
				if (ls.has_prefix("|")) {
					lsp = ls.split("|");
					if (lsp[(lsp.length - 1)].strip() == "") {
						rc += 1; amtable = true;
					}
				} else { break; }
			}
			if (dospew) { print("[%d]%s\t\tfindtable counted %d rows\n",t,tabs,rc); }
			if (rc > 0 && tln > 0) {
				string[,] matx = new string[rc,cc];
				int r = 0;
				for(t = tln; t < (tln + rc); t++) {
					ls = lines[t].strip();
					lsp = ls.split("|");
					if ((lsp.length - 2) != cc) {

// probably hit a hline...
						string[] dsp = ls.replace("|","").split("+");
						if (dospew) { print("[%d]%s\t\tfindtable comparing hline segs (%d) with columns (%d)\n",t,tabs,dsp.length,cc); }
						if (dsp[0][0] == '-' && dsp.length == cc) {
							if (dospew) { print("[%d]%s\t\tfindtable encountered a hline: %s\n",t,tabs,ls); }
							lsp = {""};
							for (int d = 0; d < dsp.length; d++) {
								lsp += dsp[d];
							}
							lsp += "";
							
							for (int c = 1; c < (lsp.length - 1); c++) { matx[r,(c - 1)] = lsp[c].strip(); }
						} else {
							if (dospew) { print("[%d]%s\t\tfindtable encountered a malformed table row: %s\n",t,tabs,dsp[0]); }
							if (dospew) { print("[%d]%sfindtable aborted.\n",t,tabs); }
							return t;
						}
					} else {
						for (int c = 1; c < (lsp.length - 1); c++) { matx[r,(c - 1)] = lsp[c].strip(); }
					}
					r += 1;
				}
				string csv = "";
				for (int i = 0; i < rc; i++) {
					for (int q = 0; q < cc; q++) {
						csv = csv.concat(matx[i,q],";");
					}
					csv = csv.concat("\n");
				}
				if (dospew) { print("[%d]%s\t\tfindtable comparing t (%d) with (tln + rc) (%d)\n",t,tabs,t,(tln + rc)); }
				if (dospew) { print("[%d]%s\t\tfindtable looking for formulae...\n",t,tabs); }
				string[] themaths = {};
				string[] themathvars = {};
				string[] themathorgvars = {};
				int f = 0;

// search up to 10 lines for formulae - this should be exposed as a param in future
				for (f = t; f < (t + 10); f++) {
					ls = lines[f].strip();
					if (ls.has_prefix("#+TBLFM:") == false && ls != "") { break; }
					if (ls.has_prefix("#+TBLFM:")) {
						ls = ls.replace("#+TBLFM:","");
						lsp = ls.split("::");
						for (int m = 0; m < lsp.length; m++) {
							if ((lsp[m].strip() in themaths) == false) {
								if (dospew) { print("[%d]%s\t\t\tfindtable found formula: %s\n",f,tabs,lsp[m].strip()); }
								themaths += lsp[m].strip();
								string[] mp = lsp[m].strip().split("=");
								if (mp.length > 1) {
									int ms = mp[1].index_of("\'(org-sbe");
									if (ms > -1) {
										int sbein = ms;
										if (dospew) { print("[%d]%s\t\t\t\tfindtable search for org-sbe after \'=\': %d\n",f,tabs,ms); }
										string mc = mp[1].substring((ms+9),(mp[1].length - (ms+9)));
										if (dospew) { print("[%d]%s\t\t\t\tfindtable removed org-sbe: %s\n",f,tabs,mc); }
										ms = mc.index_of("\"");
										if (ms > -1 && ms < 3) {  
											mc = mc.substring((ms+1),(mc.length - (ms+1)));
											if (dospew) { print("[%d]%s\t\t\t\tfindtable removed leading \": %s\n",f,tabs,mc); }
											ms = mc.index_of("\"");
											if (ms > 0) {
												mc = mc.substring(0,ms);
												if (dospew) { print("[%d]%s\t\t\t\tfindtable extracted variable: %s\n",f,tabs,mc); }
												if (mc != "") {
													if( sbein < lsp[m].length) {
														themathvars += mc;
														mc = lsp[m].substring(sbein,(lsp[m].length - sbein));
														themathorgvars += mc;
														if (dospew) { print("[%d]%s\t\t\t\t\tfindtable found variable (%s) in formula: %s\n",f,tabs,themathvars[(themathvars.length - 1)],mc); }
													} 
												}
											}
										}
									}
								}
							}
						}
					}
				}
				if (csv != "") {
					element ee = element();
					ee.name = tablename;
					ee.type = "table";
					ee.id = makemeahash(ee.name,(tln+rc));
					output oo = output();
					oo.name = makemeauniqueoutputname(tablename.concat("_spreadsheet"));
					oo.id = makemeahash(oo.name,(tln+rc));
					oo.value = csv;
					oo.ebuff = ee.id;
					outputs += oo;
					ee.outputs += &outputs[(outputs.length - 1)];
					ee.obuff += oo.id;
					if (themaths.length > 0) {
						string fml = string.joinv("\n",themaths);
						param ii = param();
						ii.type = "formula";
						ii.name = tablename.concat("_formulae");
						ii.id = makemeahash(ii.name,(tln+rc));
						ii.value = fml;
						if (themathvars.length > 0 && themathvars.length == themathorgvars.length) {
							for(int x = 0; x < themathvars.length; x++) {
								input ff = input();
								ff.name = themathvars[x];
								ff.id = makemeahash(ff.name,f);

// org-sbe vals need to be obtained after an eval
// so we just store its org syntax for now
								ff.org = themathorgvars[x];
								ff.ebuff = ee.id;
								inputs += ff;
								ee.inputs += &inputs[(inputs.length - 1)];
								ee.ibuff += ff.id;
							}
						}
						ee.params += ii;
						t = f;
					}
// move carrot to next line after table block, search up to 10 lines forward...
					for (f = t; f < (t + 10); f++) {
						if (lines[t].strip().has_prefix("#+END_TABLE")){ t = (f + 1); break; }
					}
					typecount[4] += 1;
					ee.owner = &headings[hidx];
					ee.hbuff = headings[hidx].id;
					elements += ee;
					headings[hidx].elements += &elements[(elements.length - 1)];
					headings[hidx].ebuff += ee.id;
					elementownsio((elements.length - 1));
					if (dospew) { print("[%d]%sfindtable captured a table element.\n",t,tabs); }
					int64 ttte = GLib.get_real_time();
					if (spew) { print("\nfind table took %f microseconds\n\n",((double) (ttte - ttts)));}
					return (t);
				}
			}
		}
	}
	if (dospew) { print("[%d]%sfindtable found nothing.\n",l,tabs); }
	int64 ttte = GLib.get_real_time();
	if (spew) { print("\nfind table took %f microseconds\n\n",((double) (ttte - ttts)));}
	return (l + 1);
}

int findsrcblock (int l,int ind, string n) {
	int64 stts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindsrcblock started...\n",l,tabs); }
	string ls = lines[l].strip();
	string[] srcblock = {};
	int b = l;
	if (ls.has_prefix("#+BEGIN_SRC")) {
		if (spew) { print("[%d]%sfound src header: %s\n",l,tabs,lines[l]); }
		for (b = l; b < lines.length; b++) {
			srcblock += lines[b];
			if (lines[b].strip().has_prefix("#+END_SRC")) {
				if (spew) { print("[%d]%s\tcaptured source block\n",b,tabs); }
				break;
			}
		}
	}
	if (srcblock.length > 2) {
		string nwn = n;
		if (n == "") { nwn =  "srcblock_%d".printf(typecount[2]); }
		element ee = element();
		ee.type = "srcblock";
		ee.name = nwn;
		ee.id = makemeahash(nwn,b);

// turn src code into a local param
		if (spew) { print("[%d]%s\tsrc block line count is %d\n",b,tabs,srcblock.length); }
		string src = "";
		for (int k = 1; k < (srcblock.length - 1); k++) {
			src = src.concat(srcblock[k],"\n");
		}
		src._chomp();
		param cc = param();
		cc.type = "source";
		cc.name = nwn.concat("_code");
		cc.id = makemeahash(cc.name,b);
		cc.value = src;
		ee.params += cc;
		if (spew) { print("[%d]%s\tsrc block code stored as parameter: %s\n",b,tabs,cc.name); }

// turn src type into local parameter
		string[] hp = srcblock[0].split(":");
		if (spew) { print("[%d]%s\tlooking for type: %s\n",b,tabs,hp[0]); }
		string[] hpt = hp[0].split(" ");
		if (hpt.length > 1) {
			if (hpt[1] != null) { 
				if (hpt[1] != "") {
					param tt = param();
					tt.type = "language";
					tt.name = "language";
					tt.id = makemeahash(tt.name,b);
					tt.value = hpt[1];
					ee.params += tt;
					if (spew) { print("[%d]%s\t\tstored type parameter: %s\n",b,tabs,hpt[1]); }
				}
			}
		}

// get header args
		for (int m = 1; m < hp.length; m++) {
			bool notavar = false;
			if (spew) { print("[%d]%s\tparsing header arg: %s\n",b,tabs,hp[m]); }
			if (hp[m].length > 3) {

// turn vars into inputs, sources are checked in a post-process, as the source may not exist yet
// check this with foreign language vars
				if (hp[m].has_prefix("var ")) {
					if (spew) { print("[%d]%s\t\tfound vars: %s\n",b,tabs,hp[m]); }
					string[] v = hp[m].split("=");
					v[0] = v[0].replace("var ","").strip();
					string[] hvars = {v[0]};
					for (int s = 0; s < v.length; s++) {
						string st = v[s].strip();
						if (st != "") {
							string c = st.substring(0,1);
							string d = "\"({[\'";
							if (d.contains(c)) {
								if (st.has_prefix(c)) {
									if (c == "(") { c = ")"; }
									if (c == "[") { c = "]"; }
									if (c == "{") { c = "}"; }
									if (c == "<") { c = ">"; }
									int lidx = st.last_index_of(c) + 1;
									string vl = st.substring(0,lidx);
									string vr = st.substring(lidx).strip();
									lidx = vr.index_of(" ") + 1;
									if (lidx > 0 && lidx <= st.length) {
										vr = vr.substring(lidx).strip();
									}
									hvars += vl;
									hvars += vr;
								}
							} else {
								int lidx = st.index_of(" ") + 1;
								if (lidx > 0 && lidx <= st.length) {
									string vl = st.substring(0,lidx);
									string vr = st.substring(lidx).strip();
									hvars += vl;
									hvars += vr;
								}
							}
						}
					}
					if ((hvars.length & 1) != 0) {
						hvars[(hvars.length - 1)] = null;
					}
					for (int p = 0; p < hvars.length; p++) {
						if (hvars[p] != null) {
							if (spew) { print("[%d]%s\t\tvar pair: %s, %s\n",b,tabs,hvars[p],hvars[(p+1)]); }
							input ip = input();
							ip.org = "%s=%s".printf(hvars[p],hvars[(p+1)]);	// org syntax

// removed to sacrifice speed for org-compatibility
/*
							if (hvars[(p+1)].contains("org-entry-get")) {
								if (spew) { print("[%d]%s\t\tsyncing var name with org-entry-get...\n",b,tabs); }
								int sq = hvars[(p+1)].index_of("\"") + 1;
								int eq = hvars[(p+1)].last_index_of("\"");
								if (sq < eq) {
									if (spew) { print("[%d]%s\t\t\trenamed %s",b,tabs,hvars[p]); }
									hvars[p] = hvars[(p+1)].substring(sq,(eq-sq));
									if (spew) { print(" to %s\n",hvars[p]); }
								}
							}
*/
							ip.name = hvars[p];								// name
							ip.id = makemeahash(ip.name, b);							// id, probably redundant
							ip.value = hvars[(p+1)];							// value - volatile
							ip.defaultv = hvars[(p+1)];						// fallback value
							ip.ebuff = ee.id;
							inputs += ip;
							ee.inputs += &inputs[(inputs.length - 1)];
							ee.ibuff += ip.id;
						} else { break; }
						p += 1;
					}
				} else { notavar = true; }
			}
			if (spew) { print("[%d]%s\tdone checking header vars...\n",b,tabs); }

// turn the other args into local params, check for enclosures
			if (notavar && hp[m] != null) {
				if (spew) { print("[%d]%s\tchecking header params...\n",b,tabs); }
				if (hp[m].length > 2) {
					string[] v = hp[m].split(" ");
					string[] o = {};
					for (int g = 0; g < v.length; g++) {
						if (v[g] != null && v[g] != "") {
							string s = v[g].strip();
							if (spew) { print("[%d]%s\t\tchecking param part for enclosures: %s\n",b,tabs,s); }
							string c = s.substring(0,1);
							string d = "\"({[\'";
							if (d.contains(c)) {
								if (s.has_prefix(c)) {
									if (c == "(") { c = ")"; }
									if (c == "[") { c = "]"; }
									if (c == "{") { c = "}"; }
									if (c == "<") { c = ">"; }
									int lidx = s.last_index_of(c) + 1;
									string vl = s.substring(0,lidx);
									if (spew) { print("[%d]%s\t\t\tenclosures found, capturing: %s\n",b,tabs,vl); }
									o += vl;
								}
							} else {
								if (spew) { print("[%d]%s\t\t\tno enclosures found\n",b,tabs); }
								o += s;
							}
						}
					}
					for (int p = 0; p < o.length; p++) {
						if (o[p] != null) {
							
							if (spew) { print("[%d]%s\t\tparam name val pair: %s, %s\n",b,tabs,o[p],o[(p+1)]); }
							param pp = param();
							pp.type = o[p];
							pp.name = o[p];			// name
							pp.id = makemeahash(pp.name,b);
							pp.value = o[(p+1)];		// value - volatile
							ee.params += pp;
						} else { break; }
						p += 1;
					}
				}
			}
		}

// make placeholder output
		output rr = output();
		rr.name = makemeauniqueoutputname(nwn.concat("_result"));
		rr.id = makemeahash(rr.name,b);

		if (spew) { print("[%d]%sfindsrcblock stored placeholder output: %s.\n",b,tabs,rr.name); }

		if (spew) { print("[%d]%ssearching for result...\n",b,tabs); }
		string resblock = "";
		bool amresult = false;
		int c = (b + 1);
		for (c = (b + 1); c < lines.length; c++) {
			string cs = lines[c].strip();
			if (spew) { print("[%d]%s\tlooking for result in: %s\n",c,tabs,lines[c]); }

// skip newlines
			if (cs != "") {
				if (amresult) {
					if (cs.has_prefix(": ")) { 
						resblock = resblock.concat(lines[c],"\n");
					} else { 
						if (spew) { print("[%d]%s\t\treached end of results...\n",c,tabs); }
						break;
					}
				} else {
					if (cs.has_prefix("#+NAME:")) {
						string[] csp = cs.split(" ");
						if (csp.length == 2) {
							rr.name = csp[1];
							rr.id = makemeahash(rr.name,c);
							if (spew) { print("[%d]%s\t\tfound a capturing NAME, using it to name result: %s\n",c,tabs,cs); }
							continue;
						} else {
							if (spew) { print("[%d]%s\t\thit a non-capturing NAME: %s\n",c,tabs,cs); }
							break;
						}
					}
					if (cs.has_prefix("#+RESULTS:")) {
						if (spew) { print("[%d]%s\t\tfound start of results block: %s\n",c,tabs,cs); }
						amresult = true; continue;
					} else {
						if (spew) { print("[%d]%s\tsomething blocked the result: %s\n",c,tabs,cs); }
						break;
					}
				}
			}
		}
		resblock._chomp();
		rr.value = resblock;
		rr.ebuff = ee.id;
		outputs += rr;
		ee.outputs += &outputs[(outputs.length - 1)];
		ee.obuff += rr.id;
		ee.owner = &headings[hidx];
		ee.hbuff = headings[hidx].id;
		elements += ee;
		headings[hidx].elements += &elements[(elements.length - 1)];
		headings[hidx].ebuff += ee.id;
		elementownsio((elements.length - 1));
		typecount[2] += 1;
		if (spew) { print("[%d]%sfindsrcblock ended.\n",c,tabs); }
		int64 stte = GLib.get_real_time();
		if (spew) { print("\nfind srcblock took %f microseconds\n\n",((double) (stte - stts)));}
		return c;
	}
	if (spew) { print("[%d]%sfindsrcblock found nothing.\n",l,tabs); }
	int64 stte = GLib.get_real_time();
	if (spew) { print("\nfind srcblock took %f microseconds\n\n",((double) (stte - stts)));}
	return l;
}

int findpropbin(int l, int ind) {
	int64 ptts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindpropbin started...\n",l,tabs); }
	string ls = lines[l].strip();
	bool allgood = false;
	if (ls == ":PROPERTIES:") {

// check it
		for (int b = l; b < lines.length; b++) {
			//propbin = propbin.concat(lines[b],"\n");
			if (lines[b].strip() == ":END:") {
				allgood = true; break;
			}
		}

// make it
		if (allgood) {
			element ee = element();
			ee.type = "propertydrawer";
			ee.name = "propertydrawer_%d".printf(typecount[1]);
			ee.id = makemeahash(ee.name,l);
			for (int b = (l + 1); b < lines.length; b++) {
				if (lines[b].strip() == ":END:") { 
					ee.owner = &headings[hidx];
					ee.hbuff = headings[hidx].id;
					elements += ee;
					headings[hidx].elements += &elements[(elements.length - 1)];
					headings[hidx].ebuff += ee.id;
					elementownsio((elements.length - 1));
					typecount[1] += 1;
					if (spew) { print("[%d]%sfindpropbin captured propbin %s\n",b,tabs,ee.name); }
					if (spew) { print("[%d]%sfindpropbin ended.\n",b,tabs); }
					int64 ptte = GLib.get_real_time();
					if (spew) { print("\nfind propbin took %f microseconds\n\n",((double) (ptte - ptts))); }
					return b; 
				}
				string[] propparts = lines[b].split(":");
				if (propparts.length > 2 && propparts[0].strip() == "") {
					output o = output();
					o.name = makemeauniqueoutputname(propparts[1].strip());
					o.value = propparts[2].strip();
					o.id = makemeahash(o.name,b);
					o.ebuff = ee.id; 
					outputs += o;
					ee.outputs += &outputs[(outputs.length - 1)];
					ee.obuff += o.id;
					if (spew) { print("[%d]%s\tcaptured property: %s = %s\n",b,tabs,o.name,o.value); }
				}
			}

// don't collect the element if :END: isn't reached for some reason
		}
	}
	int64 ptte = GLib.get_real_time();
	if (spew) { print("\nfind propbin took %f microseconds\n\n",((double) (ptte - ptts))); }
	if (spew) { print("[%d]%sfindpropbin found nothng.\n",l,tabs); }
	return l;
}

int findheading (int l, int ind) {
	int64 htts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) {  print("[%d]%sfindheading started...\n",l,tabs); }
	string ls = lines[l].strip();
	if (ls.has_prefix("*")) {
		heading aa = heading();
		aa.name = ls.replace("*","").strip();
		aa.id = makemeahash(aa.name,l);
		if (spew) { print("[%d]%s\tcollecting indentation...\n",l,tabs); }
		int c = 0;
		aa.stars = 0;
		while (ls.get_char(c) == '*') {
			aa.stars = aa.stars + 1;
			c += 1;
		}
		if (spew) { print("[%d]%s\t\tindetation level is %d\n",l,tabs,c); }
		ls = ls.replace("*","");
		if (spew) { print("[%d]%s\tsearching for keywords and properties...\n",l,tabs); }
		int ts = ls.index_of("[");
		int te = ls.last_index_of("]");
		if (te > ts) {
			string tpre = ls.substring(ts,((te+1)-ts));
			if (spew) { print("[%d]%s\t\tkeyword and priority: %s\n",l,tabs,tpre); }
			string[] tprep = tpre.split("]");
			if (tprep.length > 1) {
				string tdon = tprep[0].strip().concat("]");
				if (notintodonames(tdon,todos)) {
					todo tdo = todo();
					tdo.name = tdon;
					tdo.id = makemeahash(tdo.name,l);
					tdo.headings += aa.id;
					aa.todo = tdo.id;
					todos += tdo;
				} else {
					int ftdo = findtodoindexbyname(tdon,todos);
					if (ftdo < todos.length) {
						aa.todo = todos[ftdo].id;
					}
					if ((aa.id in todos[ftdo].headings) == false) {
						todos[ftdo].headings += aa.id;
					}
				}
				if (spew) { print("[%d]%s\t\t\ttodo tag: %s]\n",l,tabs,tdon); }
				aa.name = aa.name.replace(tdon,"");
				aa.name = aa.name.strip();
			}
			if (tprep.length > 2) {
				string prn = tprep[1].strip().concat("]");
				if (notinprioritynames(prn,priorities)) {
					priority pri = priority();
					pri.name = prn;
					pri.id = makemeahash(pri.name,l);
					pri.headings += aa.id;
					aa.priority = pri.id;
					priorities += pri;
				} else {
					int fpri = findpriorityindexbyname(prn,priorities);
					if (fpri < priorities.length) {
						aa.priority = priorities[fpri].id;
					}
					if ((aa.id in priorities[fpri].headings) == false) {
						priorities[fpri].headings += aa.id;
					}
				}
				if (spew) { print("[%d]%s\t\t\tpriority tag: %s]\n",l,tabs,prn); }
				aa.name = aa.name.replace(prn,"");
				aa.name = aa.name.strip();
			}
		}
		if (spew) { print("[%d]%s\tsearching for tags...\n",l,tabs); }
		string remname = aa.name;
		int gs = remname.index_of(":");
		int ge = remname.last_index_of(":");
		if (ge > gs) {
			string gstr = remname.substring(gs,((ge+1)-gs));
			if (gstr != null || gstr != "") {
				aa.name = aa.name.replace(gstr,"").strip();
				if (spew) { print("[%d]%s\t\ttags : %s\n",l,tabs,gstr); }
				string[] gpts = gstr.split(":");
				if (gpts.length > 0) {
					for (int g = 0; g < gpts.length; g++) {
						string gpn = gpts[g].strip();
						if (spew) { print("[%d]%s\t\t\ttag : %s\n",l,tabs,gpts[g]); }
						if (gpn != "") {
							if (notintagnames(gpn,tags)) {
								tag gg = tag();
								gg.name = gpts[g].strip();
								gg.id = makemeahash(gg.name,l);
								gg.headings += aa.id;
								if (spew) { print("[%d]%s\t\t\tadding new tag :%s: to heading: %s\n",l,tabs,gg.name,aa.name); }
								aa.tags += gg.id;
								if (spew) { print("[%d]%s\t\t\tadding heading: %s, to new tag :%s:\n",l,tabs,aa.name,gg.name); }
								tags += gg;
							} else {
								int ftag = findtagindexbyname(gpn,tags);
								if (ftag < tags.length) { 
									if ((tags[ftag].id in aa.tags) == false) {
										if (spew) { print("[%d]%s\t\t\tadding existing tag :%s: to heading: %s\n",l,tabs,tags[ftag].name,aa.name); }
										aa.tags += tags[ftag].id;
									}
									if ((aa.id in tags[ftag].headings) == false) {
										tags[ftag].headings += aa.id;
										if (spew) { print("[%d]%s\t\t\tadding heading: %s, to existing tag :%s:\n",l,tabs,aa.name,tags[ftag].name); }
									}
								}
							}
						}
					}
				}
			}
		}
		headings += aa;
		hidx = (headings.length - 1);
		if (spew) { print("[%d]%s\tfindheading captured a heading: %s.\n",l,tabs,aa.name); }
		if (spew) { print("[%d]%sfindheading ended.\n",(l + 1),tabs); }
		int64 htte = GLib.get_real_time();
		if (spew) { print("\nfind headng took %f microseconds\n\n",((double) (htte - htts))); }
		return (l + 1);
	}
	if (spew) { print("[%d]%sfindheading found nothng.\n",l,tabs); }
	int64 htte = GLib.get_real_time();
	if (spew) { print("\nfind headng took %f microseconds\n\n",((double) (htte - htts))); }
	return l;
}

int findname(int l, int ind) {
	int64 ntts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindname started...\n",l,tabs); }
	string ls = lines[l].strip();
	if (ls.has_prefix("#+NAME:")) {
		string[] lsp = ls.split(" ");
		if (lsp.length == 3) {
			if (spew) { print("[%d]%s\tfound a #+NAME one-liner: var=%s, val=%s\n\n",l,tabs,lsp[1],lsp[2]); }
			element ee = element();
			ee.name = "namevar_%s".printf(lsp[1]);
			ee.id = makemeahash(ee.name,l);
			ee.type = "nametag";
			output oo = output();
			oo.name = makemeauniqueoutputname(lsp[1]);
			oo.id = makemeahash(oo.name,l);;
			oo.value = lsp[2];
			oo.ebuff = ee.id;
			outputs += oo;
			ee.outputs += &outputs[(outputs.length - 1)];
			ee.obuff += oo.id;
			ee.owner = &headings[hidx];
			ee.hbuff = headings[hidx].id;
			elements += ee;
			headings[hidx].elements += &elements[(elements.length - 1)];
			headings[hidx].ebuff += ee.id;
			elementownsio((elements.length - 1));
			typecount[6] += 1;
			if (spew) { print("[%d]%s\t\tfindname captured a namevar\n",l,tabs); }
			if (spew) { print("[%d]%sfindname ended.\n",(l + 1),tabs); }
			return (l + 1); 
		}
		if (lsp.length == 2) {
			if (spew) { print("[%d]%s\tfound a capturing #+NAME: %s, looking for something to capture...\n",l,tabs,lsp[1]);}
			for (int b = (l + 1); b < lines.length; b++) {
				if (spew) { print("[%d] = %s\n",b,lines[b]);}
				if (lines[b] != "") {
					string bs = lines[b].strip();
					if (bs.has_prefix("#+BEGIN_SRC")) {
						if (spew) { print("[%d]%s\t\tfound a src block to capture...\n",b,tabs);}
						int n = findsrcblock(b,(ind+16),lsp[1]);
						return n;
					}
					if (bs.has_prefix("#+BEGIN_EXAMPLE")) {
						if (spew) { print("[%d]%s\t\tfound an example block to capture...\n",b,tabs);}
						int n = findexample(b,(ind+16),lsp[1]);
						return n;
					}
					if (bs.has_prefix("#+BEGIN_TABLE")) {
						if (spew) { print("[%d]%s\t\tfound a table to capture...\n",b,tabs);}
						int n = findtable(b,(ind+16),lsp[1]);
					}
					if (spew) { print("[%d]%sfindname found nothing.\n",b,tabs);}
					return b;
				} else {
					if (spew) { print("[%d]%s\t\tskipping empty line...\n",b,tabs);}
				}
			}
		}
	}
	if (spew) { print("[%d]%sfindname found nothing.\n",l,tabs);}
	int64 ntte = GLib.get_real_time();
	if (spew) { print("\nfind name took %f microseconds\n\n",((double) (ntte - ntts)));}
	return l;
}
int searchfortreasure (int l, int ind) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%ssearchingfortreasure...\n",l,tabs);}
	string ls = lines[l].strip();
	ind += 4;
	int n = l;
	if (ls.has_prefix("*")) { n = findheading(l,ind); }
	if (hidx >= 0) {
		if (lines[n].strip().has_prefix("*")) { return n; } // bail if rolling into another heading...
		if(ls.has_prefix(":PROPERTIES:")) { 
			n = findpropbin(n,ind); 
		} else {
			if(ls.has_prefix("#+NAME:")) { 
				n = findname(n,ind);
			} else {
				if(ls.has_prefix("#+BEGIN_SRC")) { 
					n = findsrcblock(n,ind,"");
				} else {
					if(ls.has_prefix("#+EXAMPLE")) { 
						n = findexample(n,ind,"");
					} else {
						if(ls.has_prefix("#+BEGIN_TABLE")) { 
							n = findtable(n,ind,"");
						} else {
							if(ls.has_prefix("#+BEGIN_EXAMPLE")) {
								n = findexample(n,ind,"");
							} else {
								n = findparagraph(n,ind);
							}
						}
					}
				}
			}
		}
	}
	if (n == l) { n += 1; }
	return n;
}

int findtodos (int l, int ind) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindtodos started...\n",l,tabs);}
	string ls = lines[l].strip();
	if (ls != "") {
		if (ls.has_prefix("#+TODO:")) {
			ls = ls.replace("#+TODO:","");
			string[] lsp = ls.split(" ");
			if (lsp.length > 0) {
				for (int t = 0; t < lsp.length; t++) {
					string tds = lsp[t].strip();
					if (tds != "") {
						if(tds[0] == '[' && tds[(tds.length - 1)] == ']') {
							for (int k = 0; k < todos.length; k++) {
								if (todos[k].name == tds) { continue; }
							}
							if (spew) { print("[%d]%s\tfindtodos capturing a todo: %s...\n",l,tabs,tds);}
							todo tt = todo();
							tt.name = tds;
							if (spew) { print("[%d]%s\tfindtodos making a todo hash...\n",l,tabs);}
							tt.id = makemeahash(tds,l);
							if (spew) { print("[%d]%s\tfindtodos adding todo to list...\n",l,tabs);}
							todos += tt;
							if (spew) { print("[%d]%s\tfindtodos captured a todo: %s\n",l,tabs,tds);}
						}
					}
				}
			}
			return l;
		}
	}
	if (spew) { print("[%d]%sfindtodos ended.\n",l,tabs);}
	return 0;
}

int findpriorities (int l, int ind) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	bool dospew = spew;
	if (dospew) { print("[%d]%sfindpriorities started...\n",l,tabs);}
	string ls = lines[l].strip();
	if (ls.has_prefix("#+PRIORITIES:")) {
		if (dospew) { print("[%d]%s\tfindpriorities found priorities line: %s\n",l,tabs,ls); }
		string mahalfabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		ls = ls.replace("#+PRIORITIES:","").strip();
		string lsp = ls.replace(" ","");
		if (lsp[0].isdigit()) {
			string[] lsps = ls.split(" ");
			if (dospew) { print("[%d]%s\t\tfindpriorities split priorities into %d vals\n",l,tabs,lsp.length); }
			if (lsps.length == 3) {
				//if (dospew) { print("a = %c, b = %c, c = %c\n",lsp[0],lsp[1],lsp[2]); }
				int aa = lsps[0].to_int();
				int bb = lsps[1].to_int();
				int cc = lsps[2].to_int();
				if (aa > -1 && bb > -1 && cc > -1) {
					if (dospew) { print("[%d]%s\t\t\taa = %d, bb = %d, cc = %d\n",l,tabs,aa,bb,cc); }
					if (aa < bb && cc <= bb && aa <= cc) {
						for (int t = aa; t <= bb; t++) {
							string tds = "%d".printf(t);
							if (tds != "") {
								tds = "[#%s]".printf(tds);
								priority pp = priority();
								pp.name = tds;
								pp.id = makemeahash(tds,l);
								priorities += pp;
								if (dospew) { print("[%d]%s\tfindpriorities captured a priority: %s\n",l,tabs,tds); }
							}
						}
					}
				}
			}
		} else {
			if (dospew) { print("[%d]%s\t\tfindpriorities split priorities into %d vals\n",l,tabs,lsp.length); }
			if (lsp.length == 3) {
				//if (dospew) { print("a = %c, b = %c, c = %c\n",lsp[0],lsp[1],lsp[2]); }
				int aa = mahalfabets.index_of(lsp[0].to_string());
				int bb = mahalfabets.index_of(lsp[1].to_string());
				int cc = mahalfabets.index_of(lsp[2].to_string());
				if (aa > -1 && bb > -1 && cc > -1) {
					//if (dospew) { print("aa = %d, bb = %d, cc = %d\n",aa,bb,cc); }
					if (dospew) { print("[%d]%s\t\t\taa = %d (%c), bb = %d (%c), cc = %d (%c)\n",l,tabs,aa,mahalfabets[aa],bb,mahalfabets[bb],cc,mahalfabets[cc]); }
					if (aa < bb && cc <= bb && aa <= cc) {
						for (int t = aa; t <= bb; t++) {
							string tds = (mahalfabets[t].to_string());
							if (tds != "") {
								tds = "[#%s]".printf(tds);
								priority pp = priority();
								pp.name = tds;
								pp.id = makemeahash(tds,l);
								priorities += pp;
								if (dospew) { print("[%d]%s\tfindpriorities captured a priority: %s\n",l,tabs,tds); }
							}
						}
					}
				}
			}
		}
		return l;
	}
	if (dospew) { print("[%d]%sfindpriorities ended.\n",l,tabs);}
	return 0;
}

void loadmemyorg (string defile) {
	print("loadmemyorg: loading %s\n",defile);
// test file override
	string ff = Path.build_filename ("./", defile);
	File og = File.new_for_path(ff);
	if (og.query_exists() == true) {
		string sorg = "";
		try {
			uint8[] c; string e;
			og.load_contents (null, out c, out e);
			sorg = (string) c;
			if (spew) { print("\ttestme.org loaded.\n"); }
		} catch (Error e) {
			print ("\tfailed to read %s: %s\n", og.get_path(), e.message);
		}
		if (sorg.strip() != "") {
			print("loadmemyorg: clearing the arrays...\n");

			headings = {};
			elements = {};
			params = {};
			inputs = {};
			outputs = {};
			typecount = {0,0,0,0,0,0,0};
			tags = {};
			priorities = {};
			todos = {};
			lines = {};
			sel = -1;
			hidx = -1;

			print("loadmemyorg: headings.length   = %d\n",headings.length);
			print("loadmemyorg: elements.length   = %d\n",elements.length);
			//print("loadmemyorg: params.length     = %d\n",params.length);
			print("loadmemyorg: inputs.length     = %d\n",inputs.length);
			print("loadmemyorg: outputs.length    = %d\n",outputs.length);
			print("loadmemyorg: tags.length       = %d\n",tags.length);
			print("loadmemyorg: priorities.length = %d\n",priorities.length);
			print("loadmemyorg: todos.length      = %d\n",todos.length);
// type counts, used to name un-named elements on creation, not used for renaming
// this will change in future, so replace it with something more descriptive
// typecount[0] = paragraph element count
// typecount[1] = propertydrawer element count
// typecount[2] = un-named srcblock element count
// typecount[3] = un-named example element count
// typecount[4] = un-named table element count
// typecount[5] = command element count
// typecount[6] = nametags - not useful as they're already named, just counting them here
			typecount = {0,0,0,0,0,0,0};
			headingname = "";
			string srcname = "";
			string ls = "";
			print("\nreading lines...\n");
			lines = sorg.split("\n");
			print("loadmemyorg: %d lines read OK.\n",lines.length);
			int todoline = 0;
			int priorityline = 0;
			int i = 0;
			spew = true;
// harvest
// allow up to 100 lines of config, then stop searching for todos and priorities
// stop searching for config after 2nd heading
			while (i < lines.length) {
				if (todoline == 0 && i < 100 && headings.length < 3) { todoline = findtodos(i,1); }
				if (priorityline == 0 && i < 100 && headings.length < 3) { priorityline = findpriorities(i,1); }
				if (spew) { print("[%d] = %s\n",i,lines[i]); }
				i = searchfortreasure(i,1);
			}
			if(spew) { print("testparse harvested:\n\t%d headings\n\t%d nametags\n\t%dproperty drawers\n\t%d src blocks\n\n",headings.length,typecount[5],typecount[1],typecount[2]); }
			if (headings.length > 0) 
				hidx = 0;{
				indexheadings();
				indexelements();
				indexinputs();
				indexoutputs();
				if (spew) { print("loadmemyorg crosslink starting....\n"); }
				int64 cxts = GLib.get_real_time();
				buildpath();
				crosslinkio();
				int64 cxte = GLib.get_real_time();
				if (spew) { print("\ncrosslink took %f microseconds\n\n",((double) (cxte - cxts)));}
				sel = headings[0].id;
			}
		} else { print("Error: orgfile was empty.\n"); }
	} else { print("Error: couldn't find orgfile.\n"); }
	if (spew) { print("loadmemyorg finsished.\n"); }
}

void restartui(int ww) {
	modeboxes = {};
	ModalBox panea = new ModalBox(0,0);
	ModalBox paneb = new ModalBox(1,1);
	modeboxes += panea;
	modeboxes += paneb;
	vdiv.get_first_child().destroy();
	vdiv.get_last_child().destroy();
	vdiv.start_child = modeboxes[0];
	modeboxes[0].content.append(new Outliner(hidx,modeboxes[0].id));
	vdiv.end_child =  modeboxes[1];
	modeboxes[1].content.append(new ParamBox(modeboxes[1].id));
}

//    ____________  ____   ____  ____________
//---/*           \/*   \ /*   \/*           \------------+ *
//  /  .          .\ .   \  `   \ *. .*      .\
//--\       \   ___/      \      \    `    \  /-------------+ *
//---\       \_/*   \      \      \    .    \/----------------+ *
//    \       \__`   \      \__    \  __*    \___
//     \   .          \ .           \/*          \
//------\   *.       .*\ *.        .*\ *.       .*\---------+ *
//-------\             /             /            /--------+ *
//        \___________/\____________/\___________/
//--------------------------------------------------------------+ *

public class frownedupon :  Gtk.Application {
	construct { application_id = "com.cpbrown.frownedupon"; flags = ApplicationFlags.FLAGS_NONE; }
}

// ui containers within containters within containers...

public class OutputRow : Gtk.Box {
	private Gtk.Entry outputvar;
	private Gtk.Box outputcontainer;
	private Gtk.Entry outputval;
	private Gtk.ToggleButton outputshowval;
	private string oupcss;
	private Gtk.CssProvider oupcsp;
	private Gtk.TextTagTable outputvaltextbufftags;
	private GtkSource.Buffer outputvaltextbuff;
	private GtkSource.View outputvaltext;
	private Gtk.ScrolledWindow outputvalscroll;
	private Gtk.Box outputscrollbox;
	private Gtk.Box outputsubrow;
	private Gtk.TextTag outputvaltextbufftag;
	private int[,] mydiffs;
	private Gtk.ToggleButton outputvalmaxi;
	private Gtk.DragSource oututrowdragsource;
	private Gtk.EventControllerFocus outputvalevc;
	private bool edited;
	public uint elementid;
	public uint outputid;
	private string evalmyparagraph(int h,int e,int o) {
		int ee = getelementindexbyid(elementid);
		int oo = getoutputindexbyid(outputid);
		if (ee >= 0 && oo >= 0) {
			string v = outputs[oo].value;
			int[,] tdif = new int[elements[ee].inputs.length,2];
			for (int i = 0; i < elements[ee].inputs.length; i++) {
				string k = elements[ee].inputs[i].defaultv;
				string n = elements[ee].inputs[i].source.value;
				if (k != "" && n != "") {
					int aa = v.index_of(k) + 1; //print("aa = %d\n",aa);
					v = v.replace(k,n);
					int bb = aa + (n.length + 1); //print("bb = %d\n",bb);
					if (aa < bb) { tdif[i,0] = aa; tdif[i,1] = bb; }
				}
			}
			mydiffs = tdif;
			return v;
		}
		return "";
	}
	public OutputRow (int e, int idx) {
		elementid = elements[e].id;
		outputid = outputs[idx].id;
		print("OUTPUTROW: started (%d, %d)\n",e,idx);
		print("OUTPUTROW: element[%d] %s, output[%d] %s)\n",e,elements[e].name,idx,outputs[idx].name);
		edited = false;
		if (idx < outputs.length) {
			outputvar = new Gtk.Entry();
			outputvar.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			outputvar.get_style_context().add_class("xx");
			outputvar.margin_start = 0;
			outputvar.margin_end = 0;
			outputvar.hexpand = true;
			outputvar.set_text(outputs[idx].name);
			outputcontainer = new Gtk.Box(VERTICAL,4);
			outputcontainer.hexpand = true;

// one-liners
			print("OUTPUTROW: checking for one-liners...\n");
			if (elements[e].type == "nametag" || elements[e].type == "propertydrawer") {
				outputcontainer.set_orientation(HORIZONTAL);
				outputcontainer.spacing = 4;
				outputval = new Gtk.Entry();
				outputval.set_text(outputs[idx].value);
				outputval.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
				outputval.get_style_context().add_class("xx");
				outputval.hexpand = true;
				outputvar.margin_start = 0;
				outputvar.margin_end = 0;
				outputcontainer.append(outputvar);
				outputcontainer.append(outputval);

// edit output val one-liner
				outputval.changed.connect(() => {
					if (doup) {
						int ee = getelementindexbyid(elementid);
						int oo = getoutputindexbyid(outputid);
						if (ee >= 0) {
							doup = false;
							if (outputval.text.strip() != "") {
								outputs[oo].value = outputval.text.strip();
							}
							doup = true;
						}
					}
				});
			}

// edit output name
			print("OUTPUTROW: adding output name signal...\n");
			outputvar.changed.connect(() => {
				if (doup) {
					int ee = getelementindexbyid(elementid);
					int oo = getoutputindexbyid(outputid);
					if (ee >= 0) {
						doup = false;
						if (outputvar.text.strip() != "") {
							string nn = renameuniqueoutputname(outputvar.text,outputs[oo].id,elements[ee].type);
							nn = nn.strip();
							outputs[oo].name = nn;
						}
						doup = true;
					}
				}
			});

// editable multiline text outputs
			if (elements[e].type == "paragraph" || elements[e].type == "example" || elements[e].type == "srcblock") {
				print("OUTPUTROW: adding gtksourceview field for %s\n",elements[e].type);
				outputsubrow = new Gtk.Box(HORIZONTAL,4);
				outputsubrow.append(outputvar);
				outputscrollbox = new Gtk.Box(VERTICAL,10);
				outputvalscroll = new Gtk.ScrolledWindow();
				outputvalscroll.height_request = 200;
				outputvaltextbufftags = new Gtk.TextTagTable();
				outputvaltextbuff = new GtkSource.Buffer(outputvaltextbufftags);
				outputvaltext = new GtkSource.View.with_buffer(outputvaltextbuff);
				outputvaltext.buffer.set_text(outputs[idx].value);
				outputvaltext.accepts_tab = true;
				outputvaltext.set_monospace(true);
				outputvaltext.tab_width = 2;
				outputvaltext.indent_on_tab = true;
				outputvaltext.indent_width = 4;
				outputvaltext.show_line_numbers = true;
				outputvaltext.highlight_current_line = true;
				outputvaltext.vexpand = true;
				outputvaltext.hexpand = true;
				outputvaltext.top_margin = 0;
				outputvaltext.left_margin = 0;
				outputvaltext.right_margin = 0;
				outputvaltext.bottom_margin = 0;
				outputvaltext.space_drawer.enable_matrix = true;
				outputvaltextbuff.set_highlight_syntax(true);
				outputvaltextbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-gifded"));

// edit
				outputvaltext.buffer.changed.connect(() => {
					if (doup) {
						int oo = getoutputindexbyid(outputid);
						outputs[oo].value = outputvaltext.buffer.text;
						edited = true;
					}
				});

// refresh inputs for paragraph
				if (elements[e].type == "paragraph") {
					print("OUTPUTROW: adding val-var handling for %s\n",elements[e].type);
					outputvalevc = new Gtk.EventControllerFocus();
					outputvaltext.add_controller(outputvalevc);
					outputvalevc.leave.connect(() => {
						if (doup && edited) {
							int oo = getoutputindexbyid(outputid);
							int ee = getelementindexbyid(elementid);
							bool vvl = updatevalvarlinks(outputvaltext.buffer.text,hidx,ee);
							if (vvl) {
								doup = false;

//this <- paraoutputlistbox <- paraoutputbox <- parabox <- ElementBox
								ElementBox pbox = ((ElementBox) this.parent.parent.parent.parent);
								while (pbox.elminputlistbox.get_first_child() != null) {
									pbox.elminputlistbox.remove(pbox.elminputlistbox.get_first_child());
								}
								for (int i = 0; i < elements[ee].inputs.length; i++) {
									InputRow elminputrow = new InputRow(e,i);
									pbox.elminputlistbox.append(elminputrow);
								}
								doup = true;
							}
							edited = false;
						}
					});
				}

// expand toggle
				outputvalmaxi = new Gtk.ToggleButton();
				outputvalmaxi.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				outputvalmaxi.get_style_context().add_class("xx");
				outputvalmaxi.icon_name = "view-fullscreen";

// paragraph is a special case as it may require eval, but isn't a param that creates an output like srcblock...
				if (elements[e].type == "paragraph") {
					print("OUTPUTROW: adding paragraph eval button...\n");
					outputshowval = new Gtk.ToggleButton();
					outputshowval.icon_name = "user-invisible";
					outputshowval.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
					outputshowval.get_style_context().add_class("xx");
					outputshowval.toggled.connect(() => {
						doup = false;
						int oo = getoutputindexbyid(outputid);
						int ee = getelementindexbyid(elementid);
						if (outputshowval.active) {
							string outval = evalmyparagraph(hidx,ee,oo);
							outputvaltext.buffer.set_text("(%s)".printf(outval));
							outputshowval.icon_name = "user-available";
							for (int d = 0; d < mydiffs.length[0]; d++) {
								Gtk.TextTag rg = outputvaltextbufftags.lookup("difftag_%d".printf(d));
								if (rg != null) { outputvaltextbufftags.remove(rg); }
								Gtk.TextTag tg  = new Gtk.TextTag("difftag_%d".printf(d));
								tg.background = "#00FF0030";
								outputvaltextbufftags.add(tg);
								Gtk.TextIter ss = new Gtk.TextIter();
								Gtk.TextIter ff = new Gtk.TextIter();
								outputvaltextbuff.get_iter_at_offset(out ss,mydiffs[d,0]);
								outputvaltextbuff.get_iter_at_offset(out ff,mydiffs[d,1]);
								outputvaltextbuff.apply_tag_by_name("difftag_%d".printf(d), ss, ff);
								print("OUTPUTROW:\t\thighlighting tag from %d to %d...\n",mydiffs[d,0],mydiffs[d,1]);
							}
						} else {
							outputvaltext.buffer.set_text(outputs[oo].value);
							outputshowval.icon_name = "user-invisible";
						}
						doup = true;
					});
				}
				outputsubrow.margin_top = 0;
				outputsubrow.margin_end = 4;
				outputsubrow.margin_start = 4;
				outputsubrow.margin_bottom = 0;
				outputsubrow.append(outputshowval);
				outputsubrow.append(outputvalmaxi);
				outputvalscroll.set_child(outputvaltext);
				outputvaltext.vexpand = true;
				outputcontainer.append(outputsubrow);
				outputcontainer.append(outputvalscroll);
				outputvalmaxi.toggled.connect(() => {

// ModalBox/box(content)/ParamBox/scrolledWindow(pscroll)/box(pbox)/ElementBox/box(parabox)/box(paraoutputox)/box(paraoutputlistbox)/this.oututcontainer
//                          ^            ^                                                                                                       ^
//                       container     swapme                                                                                                  withme
// targ = this.parent.parent.parent.parent.parent
// src = this.outputcontainer

					if(outputvalmaxi.active) {
						outputcontainer.unparent();
						this.parent.parent.parent.parent.parent.parent.parent.set_visible(false);
						outputcontainer.set_parent(this.parent.parent.parent.parent.parent.parent.parent.parent);
						outputscrollbox.vexpand = true;
						outputcontainer.vexpand = true;
						outputvalmaxi.icon_name = "view-restore";
					} else {
						outputcontainer.unparent();
						this.parent.parent.parent.parent.parent.parent.parent.set_visible(true);
						outputscrollbox.vexpand = false;
						outputcontainer.vexpand = false;
						outputcontainer.set_parent(this);
						outputvalmaxi.icon_name = "view-fullscreen";
					}
				});
			}
			outputcontainer.vexpand = false;
			outputcontainer.margin_top = 4;
			outputcontainer.margin_start = 0;
			outputcontainer.margin_end = 0;
			outputcontainer.margin_bottom = 0;
			if (elements[e].type == "nametag" || elements[e].type == "propertydrawer") {
				outputcontainer.margin_start = 4;
				outputcontainer.margin_end = 4;
				outputcontainer.margin_bottom = 4;
			}

// some elements can't edit outputs here
			if (elements[e].type != "paragraph" && elements[e].type != "table") {
				print("add output overrides here\n");
			}
			oupcsp = new Gtk.CssProvider();
			oupcss = ".xx { background: %s;}".printf(sbhil);
			oupcsp.load_from_data(oupcss.data);
			this.get_style_context().add_provider(oupcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 0;
			this.margin_start = 0;
			this.margin_end = 0;
			this.margin_bottom = 0;
			this.append(outputcontainer);
		}
	}
}

public class ParamRow : Gtk.Box {
	private Gtk.Entry paramvar;
	private Gtk.Box paramcontainer;
	private Gtk.Entry paramval;
	private Gtk.Button parameval;
	private string prmcss;
	private Gtk.CssProvider prmcsp;
	private Gtk.TextTagTable paramvaltextbufftags;
	private GtkSource.Buffer paramvaltextbuff;
	private GtkSource.View paramvaltext;
	private Gtk.ScrolledWindow paramvalscroll;
	private Gtk.Box paramscrollbox;
	private Gtk.Box paramsubrow;
	private Gtk.TextTag paramvaltextbufftag;
	private int[,] mydiffs;
	private Gtk.ToggleButton paramvalmaxi;
	private Gtk.DragSource oututrowdragsource;
	private Gtk.EventControllerFocus paramvalevc;
	private bool edited;
	public uint elementid;
	public uint paramid;
	public ParamRow (int e, int idx) {
		print("PARAMROW: started (%d, %d)\n",e,idx);
		elementid = elements[e].id;
		paramid = elements[e].params[idx].id;
		edited = false;
		if (idx < elements[e].params.length) {
			paramvar = new Gtk.Entry();
			paramvar.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			paramvar.get_style_context().add_class("xx");
			paramvar.margin_start = 0;
			paramvar.margin_end = 0;
			paramvar.hexpand = true;
			paramvar.set_text(elements[e].params[idx].name);
			paramcontainer = new Gtk.Box(VERTICAL,4);
			paramcontainer.hexpand = true;
			entcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblin,sbhil,sbsel);

			if (elements[e].params[idx].type != "source" && elements[e].params[idx].type != "formula" && elements[e].params[idx].type != "table") {
				paramval = new Gtk.Entry();
				paramval.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				paramval.get_style_context().add_class("xx");
				paramval.set_text(elements[e].params[idx].value);
				paramvar.changed.connect(() => {
					if (doup) {
						int ee = getelementindexbyid(elementid);
						int pp = getparamindexbyid(ee,paramid);
						if (ee >= 0) {
							if (paramvar.text.strip() != "") {
								doup = false;
								elements[ee].params[pp].name = paramvar.text.strip();
								doup = true;
							}
						}
					}
				});
				paramval.changed.connect(() => {
					if (doup) {
						int ee = getelementindexbyid(elementid);
						int pp = getparamindexbyid(ee,paramid);
						if (ee >= 0) {
							if (paramval.text.strip() != "") {
								doup = false;
								elements[ee].params[pp].value = paramval.text.strip();
								doup = true;
							}
						}
					}
				});
				paramval.hexpand = true;
				paramcontainer.set_orientation(HORIZONTAL);
				paramcontainer.append(paramvar);
				paramcontainer.append(paramval);
				paramcontainer.vexpand = false;
				paramcontainer.margin_top = 4;
				paramcontainer.margin_start = 4;
				paramcontainer.margin_end = 4;
				paramcontainer.margin_bottom = 4;
			}
			paramsubrow = new Gtk.Box(HORIZONTAL,4);

// editable multiline text params
			if (elements[e].params[idx].type == "source") {
				paramsubrow.append(paramvar);
				paramscrollbox = new Gtk.Box(VERTICAL,10);
				paramvalscroll = new Gtk.ScrolledWindow();
				paramvalscroll.height_request = 200;
				paramvaltextbufftags = new Gtk.TextTagTable();
				paramvaltextbuff = new GtkSource.Buffer(paramvaltextbufftags);
				paramvaltext = new GtkSource.View.with_buffer(paramvaltextbuff);
				paramvaltext.buffer.set_text(elements[e].params[idx].value);
				paramvaltext.accepts_tab = true;
				paramvaltext.set_monospace(true);
				paramvaltext.tab_width = 2;
				paramvaltext.indent_on_tab = true;
				paramvaltext.indent_width = 4;
				paramvaltext.show_line_numbers = true;
				paramvaltext.highlight_current_line = true;
				paramvaltext.vexpand = true;
				paramvaltext.hexpand = true;
				paramvaltext.top_margin = 0;
				paramvaltext.left_margin = 0;
				paramvaltext.right_margin = 0;
				paramvaltext.bottom_margin = 0;
				paramvaltext.space_drawer.enable_matrix = true;
				paramvaltextbuff.set_highlight_syntax(true);
				paramvaltextbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-gifded"));

// edit
				paramvaltext.buffer.changed.connect(() => {
					if (doup) {
						int ee = getelementindexbyid(elementid);
						int pp = getparamindexbyid(ee,paramid);
						if (ee >= 0) {
							if (elements[ee].params.length > idx) {
								elements[ee].params[pp].value = paramvaltext.buffer.text;
								edited = true;
							}
						}
					}
				});

// expand toggle
				paramvalmaxi = new Gtk.ToggleButton();
				paramvalmaxi.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				paramvalmaxi.get_style_context().add_class("xx");
				paramvalmaxi.icon_name = "view-fullscreen";

// add eval button to src
				if (elements[e].type == "srcblock") {
					print("PARAMROW:\tadding paragraph eval button...\n");
					parameval = new Gtk.Button();
					parameval.icon_name = "media-playback-start";
					parameval.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
					parameval.get_style_context().add_class("xx");
					parameval.clicked.connect(() => {
						int ee = getelementindexbyid(elementid);
						int pp = getparamindexbyid(ee,paramid);
						if (ee >= 0 && pp >= 0) {
							if (spew) { print("PARAMROW:\tchecking inputs for %s...\n",elements[ee].name); }
							doup = false;
							int[] deps = {};
							for (int i = 0; i < elements[ee].inputs.length; i++) {
								deps += elements[ee].inputs[i].index;
							}
							if (spew) { print("PARAMROW:\tsending %d inputs to evalpath()...\n",deps.length); }
							int[] q = {};
							if (deps.length > 0) { q = evalpath(deps,elements[ee].index); }
							if (q.length == 0) { q += elements[ee].index; }
							string ctyp = ""; 
							string cmd = "";
							if (elements[ee].params[pp].name == "language") {
								ctyp = elements[ee].params[pp].value;
							}
							switch (ctyp) {
								case "vala"		: cmd = "valac"; break;
								case "python"		: cmd = "python"; break;
								case "shell"		: cmd = "sh"; break;
								case "rebol3"		: cmd = "r3"; break;
								default			: cmd = "text"; break;
							}
							for (int p = 0; p < elements[ee].params.length; p++) {
								if (elements[ee].params[p].type == "flags") {
									cmd = cmd.concat(elements[ee].params[p].name, " ", elements[ee].params[p].value, " ");
								}
							}
							print("cmd = %s\n",cmd);
							doup = true;
						}
					});
					paramsubrow.append(parameval);
				}
				paramsubrow.margin_top = 0;
				paramsubrow.margin_end = 4;
				paramsubrow.margin_start = 4;
				paramsubrow.margin_bottom = 0;
				paramsubrow.append(paramvalmaxi);
				paramvalscroll.set_child(paramvaltext);
				paramvaltext.vexpand = true;
				paramcontainer.append(paramsubrow);
				paramcontainer.append(paramvalscroll);
				paramvalmaxi.toggled.connect(() => {

// ModalBox/box(content)/ParamBox/scrolledWindow(pscroll)/box(pbox)/ElementBox/box(parabox)/box(paraparamox)/box(paraparamlistbox)/this.oututcontainer
//                          ^            ^                                                                                                       ^
//                       container     swapme                                                                                                  withme
// targ = this.parent.parent.parent.parent.parent
// src = this.paramcontainer

					if(paramvalmaxi.active) {
						paramcontainer.unparent();
						this.parent.parent.parent.parent.parent.parent.parent.set_visible(false);
						paramcontainer.set_parent(this.parent.parent.parent.parent.parent.parent.parent.parent);
						paramscrollbox.vexpand = true;
						paramcontainer.vexpand = true;
						paramvalmaxi.icon_name = "view-restore";
					} else {
						paramcontainer.unparent();
						this.parent.parent.parent.parent.parent.parent.parent.set_visible(true);
						paramscrollbox.vexpand = false;
						paramcontainer.vexpand = false;
						paramcontainer.set_parent(this);
						paramvalmaxi.icon_name = "view-fullscreen";
					}
				});
				paramcontainer.margin_start = 0;
				paramcontainer.margin_end = 0;
				paramcontainer.margin_bottom = 0;
			}

// some elements can't edit params here
			if (elements[e].type != "paragraph" && elements[e].type != "table") {
				print("add param overrides here\n");
			}
			prmcsp = new Gtk.CssProvider();
			prmcss = ".xx { background: %s;}".printf(sbhil);
			prmcsp.load_from_data(prmcss.data);
			this.get_style_context().add_provider(prmcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 0;
			this.margin_start = 0;
			this.margin_end = 0;
			this.margin_bottom = 0;
			this.append(paramcontainer);
		}
	}
}

public class InputRow : Gtk.Box {
	public Gtk.Label inputvar;
	private Gtk.Box inputcontainer;
	private Gtk.Entry inputdefvar;
	private Gtk.ToggleButton inputshowval;
	private string inpcss;
	private Gtk.CssProvider inpcsp;
	private string invcss;
	private Gtk.CssProvider invcsp;
	public uint elementid;
	public uint inputid;
	public string name;
	public InputRow (int e, int idx) {
		print("INPUTROW: started (%d, %d)\n",e,idx);
		inputid = inputs[idx].id;
		elementid = elements[e].id;
		if (idx < elements[e].inputs.length) {
			name = elements[e].inputs[idx].name;
			inputvar = new Gtk.Label(null);
			inputvar.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			inputvar.get_style_context().add_class("xx");
			inputvar.margin_start = 10;
			inputvar.set_text(elements[e].inputs[idx].name);
			inputdefvar = new Gtk.Entry();
			inputdefvar.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
			inputdefvar.get_style_context().add_class("xx");
			inputdefvar.set_text(elements[e].inputs[idx].defaultv);
			inputdefvar.hexpand = true;
			inputshowval = new Gtk.ToggleButton();
			inputshowval.icon_name = "user-invisible";
			inputshowval.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			inputshowval.get_style_context().add_class("xx");
			invcsp = new Gtk.CssProvider();
			invcss = ".xx { background: #00FFFF20; }";
			invcsp.load_from_data(invcss.data);
			inputdefvar.get_style_context().add_provider(invcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			inputdefvar.get_style_context().add_class("xx");
			inputshowval.toggled.connect(() => {
				int ii = getinputindexbyid(inputid);
				if (ii >= 0) {
					if (inputshowval.active) {
						string inval = inputs[ii].source.value;
						inputdefvar.set_text("(%s)".printf(inval));
						inputshowval.icon_name = "user-available";
						invcss = ".xx { background: #FF000020; }"; invcsp.load_from_data(invcss.data);
					} else {
						inputdefvar.set_text(inputs[ii].defaultv);
						invcss = ".xx { background: #00FFFF20; }"; invcsp.load_from_data(invcss.data);
						inputshowval.icon_name = "user-invisible";
					}
				} else {
					this.destroy();
				}
			});
			print("INPUTROW:\tinput label: %s\n",inputvar.get_text());
			inputcontainer = new Gtk.Box(HORIZONTAL,10);
			inputcontainer.append(inputvar);
			inputcontainer.append(inputdefvar);
			inputcontainer.append(inputshowval);
			inputcontainer.vexpand = false;
			inputcontainer.margin_top = 4;
			inputcontainer.margin_start = 4;
			inputcontainer.margin_end = 4;
			inputcontainer.margin_bottom = 4;

// some elements can't edit inputs here
			if (elements[e].type != "paragraph" && elements[e].type != "table") {
				print("add input overrides here\n");
			}
			inpcsp = new Gtk.CssProvider();
			inpcss = ".xx { background: %s; }".printf(sbhil);
			inpcsp.load_from_data(inpcss.data);
			this.get_style_context().add_provider(inpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 0;
			this.margin_start = 0;
			this.margin_end = 0;
			this.margin_bottom = 0;
			this.append(inputcontainer);
		}
	}
}

public class ElementBox : Gtk.Box {
	public string type;
	public string name;
	public uint elementid;
	private Gtk.Box elmbox;
	private Gtk.Box elmtitlebar;
	private Gtk.Label elmtitlelabel;
	private Gtk.Box elmnamebar;
	private Gtk.Entry elmname;
	private Gtk.Label elmnamelabel;
	private Gtk.ToggleButton elmfoldbutton;
	private Gtk.Box elminputbox;
	public Gtk.Box elminputlistbox;
	private Gtk.Label elminputlabel;
	private Gtk.Box elminputcontrolbox;
	private Gtk.ToggleButton elminputfoldbutton;
	private Gtk.CssProvider inpcsp;
	private string inpcss;
	private Gtk.Box elmoutputbox;
	private Gtk.Box elmoutputlistbox;
	private Gtk.Label elmoutputlabel;
	private Gtk.Box elmoutputcontrolbox;
	private Gtk.ToggleButton elmoutputfoldbutton;
	private Gtk.CssProvider oupcsp;
	private string oupcss;
	private Gtk.Box elmparambox;
	private Gtk.Box elmparamlistbox;
	private Gtk.Label elmparamlabel;
	private Gtk.Box elmparamcontrolbox;
	private Gtk.ToggleButton elmparamfoldbutton;
	private Gtk.CssProvider prmcsp;
	private string prmcss;
	private Gtk.CssProvider elmcsp;
	private string elmcss;
	private Gtk.CssProvider grpcsp;
	private string grpcss;
	private Gtk.DragSource elmdragsource;
	private Gtk.DropTarget elmdroptarg;
	private int dox;
	private int doy;
	public ElementBox (int idx, string typ) {
		print("ELEMENTBOX: started (%d)\n",idx);
		if (idx < elements.length) {
			this.elementid = elements[idx].id;
			this.type = elements[idx].type;
			this.name = elements[idx].name; 
			print("ELEMENTBOX:\tfound a %s element: %s\n",elements[idx].type,elements[idx].name);
			elmbox = new Gtk.Box(VERTICAL,4);
			elmtitlebar = new Gtk.Box(HORIZONTAL,0);
			elmtitlebar.margin_top = 5;
			elmtitlebar.margin_bottom = 5;
			elmtitlebar.margin_start = 5;
			elmtitlebar.margin_end = 5;
			elmtitlelabel = new Gtk.Label("%s: %s".printf(elements[idx].type,elements[idx].name));
			elmtitlelabel.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			elmtitlelabel.get_style_context().add_class("xx");
			elmtitlelabel.hexpand = true;
			elmnamebar = new Gtk.Box(HORIZONTAL,10);
			elmnamelabel = new Gtk.Label("Name:");
			elmnamelabel.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			elmnamelabel.get_style_context().add_class("xx");
			elmname = new Gtk.Entry();
			elmnamelabel.margin_start = 10;
			elmfoldbutton = new Gtk.ToggleButton();
			elmfoldbutton.icon_name = "go-up";
			elmfoldbutton.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			elmfoldbutton.get_style_context().add_class("xx");
			elmnamebar.append(elmnamelabel);
			elmnamebar.append(elmname);
			elmtitlebar.append(elmtitlelabel);
			elmtitlebar.append(elmfoldbutton);
			elmnamebar.margin_top = 4;
			elmnamebar.margin_bottom = 4;
			elmnamebar.margin_start = 4;
			elmnamebar.margin_end = 4;
			elmfoldbutton.toggled.connect(() => {
				if (elmfoldbutton.active) {
					elmfoldbutton.icon_name = "go-down";
					elmbox.visible = false;
				} else {
					elmfoldbutton.icon_name = "go-up";
					elmbox.visible = true;
				}
			});
			elmname.hexpand = true;
			elmname.get_style_context().add_provider(entcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
			elmname.get_style_context().add_class("xx");
			this.append(elmtitlebar);
			elmbox.append(elmnamebar);
			elmname.text = elements[idx].name;
			this.name = elmname.text;
			elmname.activate.connect(() => {
				int ee = getelementindexbyid(elementid);
				if (ee >= 0) {
					doup = false;
					string nn = makemeauniqueelementname(elmname.text,elements[idx].id,elements[idx].type);
					elmname.text = nn;
					elements[idx].name = nn;
					doup = true;
				}
			});
			if (elements[idx].inputs.length > 0) {
				elminputbox = new Gtk.Box(VERTICAL,4);
				elminputcontrolbox = new Gtk.Box(HORIZONTAL,4);
				elminputlistbox = new Gtk.Box(VERTICAL,0);
				elminputlistbox.margin_top = 0;
				elminputlistbox.margin_bottom = 0;
				elminputlistbox.margin_start = 0;
				elminputlistbox.margin_end = 0;
				elminputlabel = new Gtk.Label("Inputs");
				elminputlabel.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elminputlabel.get_style_context().add_class("xx");
				elminputlabel.margin_start = 10;
				elminputlabel.hexpand = true;
				elminputfoldbutton = new Gtk.ToggleButton();
				elminputfoldbutton.icon_name = "go-up";
				elminputfoldbutton.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elminputfoldbutton.get_style_context().add_class("xx");
				elminputfoldbutton.toggled.connect(() => {
					if (elminputfoldbutton.active) {
						elminputfoldbutton.icon_name = "go-down";
						elminputlistbox.visible = false;
					} else {
						elminputfoldbutton.icon_name = "go-up";
						elminputlistbox.visible = true;
					}
				});
				elminputcontrolbox.append(elminputlabel);
				elminputcontrolbox.append(elminputfoldbutton);
				elminputbox.append(elminputcontrolbox);
				elminputbox.append(elminputlistbox);
				elminputcontrolbox.margin_top = 4;
				elminputcontrolbox.margin_bottom = 4;
				elminputcontrolbox.margin_start = 4;
				elminputcontrolbox.margin_end = 4;
				inpcsp = new Gtk.CssProvider();
				inpcss = ".xx { background: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbhil);
				inpcsp.load_from_data(inpcss.data);
				elminputbox.get_style_context().add_provider(inpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elminputbox.get_style_context().add_class("xx");
				print("ELEMENTBOX:\tfetching %d inputs...\n",elements[idx].inputs.length);
				for (int i = 0; i < elements[idx].inputs.length; i++) {
					InputRow elminputrow = new InputRow(idx,i);
					elminputlistbox.append(elminputrow);
				}
				elminputlistbox.hexpand = true;
				elminputbox.hexpand = true;
				elminputbox.margin_top = 4;
				elminputbox.margin_bottom = 10;
				elminputbox.margin_start = 10;
				elminputbox.margin_end = 10;
				elmbox.append(elminputbox);
			} else {
				print("ELEMENTBOX: element %s has %d inputs\n",elements[idx].name,elements[idx].inputs.length);
			}
			if (elements[idx].params.length > 0) {
				elmparambox = new Gtk.Box(VERTICAL,4);
				elmparamcontrolbox = new Gtk.Box(HORIZONTAL,10);
				elmparamlistbox = new Gtk.Box(VERTICAL,0);
				elmparamlistbox.margin_top = 0;
				elmparamlistbox.margin_bottom = 0;
				elmparamlistbox.margin_start = 0;
				elmparamlistbox.margin_end = 0;
				elmparamlabel = new Gtk.Label("Params");
				elmparamlabel.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmparamlabel.get_style_context().add_class("xx");
				elmparamlabel.margin_start = 0;
				elmparamlabel.hexpand = true;
				elmparamfoldbutton = new Gtk.ToggleButton();
				elmparamfoldbutton.icon_name = "go-up";
				elmparamfoldbutton.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmparamfoldbutton.get_style_context().add_class("xx");
				elmparamfoldbutton.toggled.connect(() => {
					if (elmparamfoldbutton.active) {
						elmparamfoldbutton.icon_name = "go-down";
						elmparamlistbox.visible = false;
					} else {
						elmparamfoldbutton.icon_name = "go-up";
						elmparamlistbox.visible = true;
					}
				});
				elmparamcontrolbox.append(elmparamlabel);
				elmparamcontrolbox.append(elmparamfoldbutton);
				elmparambox.append(elmparamcontrolbox);
				elmparambox.append(elmparamlistbox);
				elmparamcontrolbox.margin_top = 4;
				elmparamcontrolbox.margin_bottom = 4;
				elmparamcontrolbox.margin_start = 4;
				elmparamcontrolbox.margin_end = 4;
				prmcsp = new Gtk.CssProvider();
				prmcss = ".xx { background: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbhil);
				prmcsp.load_from_data(prmcss.data);
				elmparambox.get_style_context().add_provider(prmcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmparambox.get_style_context().add_class("xx");
				print("ELMBOX:\tfetching %d params...\n",elements[idx].params.length);
				for (int i = 0; i < elements[idx].params.length; i++) {
					ParamRow elmparamrow = new ParamRow(idx,i);
					elmparamlistbox.append(elmparamrow);
				}
				elmparamlistbox.hexpand = true;
				elmparambox.hexpand = true;
				elmparambox.margin_top = 0;
				elmparambox.margin_bottom = 10;
				elmparambox.margin_start = 10;
				elmparambox.margin_end = 10;
				elmbox.append(elmparambox);
			} else {
				print("ELEMENTBOX: element %s has %d params\n",elements[idx].name,elements[idx].params.length);
			}
			if (elements[idx].outputs.length > 0) {
				elmoutputbox = new Gtk.Box(VERTICAL,4);
				elmoutputcontrolbox = new Gtk.Box(HORIZONTAL,10);
				elmoutputlistbox = new Gtk.Box(VERTICAL,0);
				elmoutputlistbox.margin_top = 0;
				elmoutputlistbox.margin_bottom = 0;
				elmoutputlistbox.margin_start = 0;
				elmoutputlistbox.margin_end = 0;
				elmoutputlabel = new Gtk.Label("Outputs");
				elmoutputlabel.get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmoutputlabel.get_style_context().add_class("xx");
				elmoutputlabel.margin_start = 0;
				elmoutputlabel.hexpand = true;
				elmoutputfoldbutton = new Gtk.ToggleButton();
				elmoutputfoldbutton.icon_name = "go-up";
				elmoutputfoldbutton.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmoutputfoldbutton.get_style_context().add_class("xx");
				elmoutputfoldbutton.toggled.connect(() => {
					if (elmoutputfoldbutton.active) {
						elmoutputfoldbutton.icon_name = "go-down";
						elmoutputlistbox.visible = false;
					} else {
						elmoutputfoldbutton.icon_name = "go-up";
						elmoutputlistbox.visible = true;
					}
				});
				elmoutputcontrolbox.append(elmoutputlabel);
				elmoutputcontrolbox.append(elmoutputfoldbutton);
				elmoutputbox.append(elmoutputcontrolbox);
				elmoutputbox.append(elmoutputlistbox);
				elmoutputcontrolbox.margin_top = 4;
				elmoutputcontrolbox.margin_bottom = 4;
				elmoutputcontrolbox.margin_start = 4;
				elmoutputcontrolbox.margin_end = 4;
				oupcsp = new Gtk.CssProvider();
				oupcss = ".xx { background: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbhil);
				oupcsp.load_from_data(oupcss.data);
				elmoutputbox.get_style_context().add_provider(oupcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				elmoutputbox.get_style_context().add_class("xx");
				print("ELMBOX:\tfetching %d outputs...\n",elements[idx].outputs.length);
				for (int i = 0; i < elements[idx].outputs.length; i++) {
					OutputRow elmoutputrow = new OutputRow(idx,elements[idx].outputs[i].index);
					elmoutputlistbox.append(elmoutputrow);
				}
				elmoutputlistbox.hexpand = true;
				elmoutputbox.hexpand = true;
				elmoutputbox.margin_top = 0;
				elmoutputbox.margin_bottom = 10;
				elmoutputbox.margin_start = 10;
				elmoutputbox.margin_end = 10;
				elmbox.append(elmoutputbox);
			}
			elmbox.margin_top = 4;
			elmbox.margin_bottom = 4;
			elmbox.margin_start = 4;
			elmbox.margin_end = 4;
			elmbox.hexpand = true;
			elmcsp = new Gtk.CssProvider();
			elmcss = ".xx { background: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sblit);
			elmcsp.load_from_data(elmcss.data);
			elmdragsource = new Gtk.DragSource();
			elmdragsource.set_actions(Gdk.DragAction.MOVE);
			elmdragsource.prepare.connect((source, x, y) => {
				dox = (int) x;
				doy = (int) y;
				return new Gdk.ContentProvider.for_value(this);
			});
			elmdragsource.drag_begin.connect((source,drag) => {
				Gtk.WidgetPaintable mm = new Gtk.WidgetPaintable(this);
				source.set_icon(mm,dox,doy);
			});
			elmdragsource.drag_cancel.connect(() => {
				return true;
			});
			this.add_controller(elmdragsource);
			elmdroptarg = new Gtk.DropTarget(typeof (ElementBox),Gdk.DragAction.MOVE);
			elmdroptarg.on_drop.connect((value,x,y) => {
				var dropw = (ElementBox) value;
				var targw = this;
				if( targw == dropw || dropw == null) { return false; } 
				Gtk.Allocation dropalc = new Gtk.Allocation(); dropw.get_allocation(out dropalc);
				Gtk.Allocation targalc = new Gtk.Allocation(); targw.get_allocation(out targalc);
				var lbx = (Gtk.Box) targw.parent;
				if (dropalc.y > targalc.y) { 
					lbx.reorder_child_after(dropw,targw);
					lbx.reorder_child_after(targw,dropw); 
				} else { lbx.reorder_child_after(dropw,targw); }
				return true;
			});
			this.add_controller(elmdroptarg);
			this.set_orientation(VERTICAL);
			this.get_style_context().add_provider(elmcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 4;
			this.margin_start = 10;
			this.margin_end = 40;
			this.margin_bottom = 4;
			this.hexpand = true;
			this.append(elmbox);
		}
	}
}

public class Outliner : Gtk.Box {
	private Gtk.Box outlinerscrollbox;
	private Gtk.ScrolledWindow outlinerscroll;
	private Gtk.Box outlinercontrolbox;
	private Gtk.Box outlinersearchbox;
	private Gtk.Box outlinerfilterbox;
	private Gtk.CssProvider olncsp;
	private string olncss;
	private Gtk.Button outlineraddheading;
	private Gtk.Button outlinerremheading;
	private Gtk.ToggleButton outlinersearchtoggle;
	private Gtk.ToggleButton outlinerfiltertoggle;
	public uint owner;
	public Outliner (int s, uint u) {
		owner = u;
		olncsp = new Gtk.CssProvider();
		olncss = ".xx { background: %s; }".printf(sbshd);
		olncsp.load_from_data(olncss.data);
		this.margin_top = 0;
		this.margin_bottom = 0;
		this.margin_start = 0;
		this.margin_end = 0;
		this.hexpand = true;
		this.set_orientation(VERTICAL);
		this.spacing = 4;
		this.get_style_context().add_provider(olncsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		this.get_style_context().add_class("xx");

		outlinerscroll = new Gtk.ScrolledWindow();
		outlinerscroll.vexpand = true;
		outlinerscrollbox = new Gtk.Box(VERTICAL,0);
		outlinerscrollbox.vexpand = true;

		if (headings.length > 0) {
			headingboxes = {};
			for (int h = 0; h < headings.length; h++) {
				HeadingBox hh = new HeadingBox(h);
				headingboxes += hh;
				outlinerscrollbox.append(headingboxes[(headingboxes.length - 1)]);
				print("OUTLINER: added heading[%d] %s\n",h,headings[h].name);
			}

		}
		outlinerfilterbox = new Gtk.Box(HORIZONTAL,4);
		outlinersearchbox = new Gtk.Box(HORIZONTAL,4);
		outlinercontrolbox = new Gtk.Box(HORIZONTAL,4);
		outlinerfilterbox.visible = false;
		outlinersearchbox.visible = false;
		outlinersearchtoggle = new Gtk.ToggleButton();
		outlinersearchtoggle.icon_name = "edit-find";
		outlinerfiltertoggle = new Gtk.ToggleButton();
		outlinerfiltertoggle.icon_name = "view-more";
		outlineraddheading = new Gtk.Button.with_label("+");
		outlinerremheading = new Gtk.Button.with_label("-");
		outlinercontrolbox.append(outlineraddheading);
		outlinercontrolbox.append(outlinerremheading);
		outlinercontrolbox.append(outlinersearchtoggle);
		outlinercontrolbox.append(outlinerfiltertoggle);
		outlinerscroll.set_child(outlinerscrollbox);
		this.append(outlinerscroll);
		this.append(outlinercontrolbox);
		this.append(outlinersearchbox);
		this.append(outlinerfilterbox);
	}
}

public class HeadingBox : Gtk.Box {
	private Gtk.Box hbox;
	private Gtk.Entry headingname;
	private Gtk.Box headinggrip;
	private Gtk.Label headingdot;
	public string hedcss;
	public Gtk.CssProvider hedcsp;
	public string nomcss;
	public Gtk.CssProvider nomcsp;
	private Gtk.MenuButton headingtodobutton;
	private Gtk.Popover headingtodopop;
	private Gtk.Box headingtodopopbox;
	private Gtk.ScrolledWindow headingtodopopscroll;
	private Gtk.GestureClick headingtodobuttonclick;
	private Gtk.MenuButton headingprioritybutton;
	private Gtk.Popover headingprioritypop;
	private Gtk.Box headingprioritypopbox;
	private Gtk.ScrolledWindow headingprioritypopscroll;
	private Gtk.GestureClick headingprioritybuttonclick;
	private Gtk.MenuButton headingtagbutton;
	private Gtk.Popover headingtagpop;
	private Gtk.Box headingtagpopbox;
	private Gtk.ScrolledWindow headingtagpopscroll;
	private Gtk.GestureClick headingtagbuttonclick;
	private Gtk.Label headingtaglist;
	private Gtk.ToggleButton headingexpander;
	private Pango.Layout headingnamelayout;
	private Gtk.GestureClick thisclick;
	public int stars;
	public uint headingid;
	public int index;
	public HeadingBox (int idx) {
		print("\nHEADINGBOX: started (idx %d) of %d.\n",idx,(headings.length - 1));
		
		if (idx < headings.length) {
			print("HEADINGBOX:\tmaking heading for: %s\n",headings[idx].name);
			stars = headings[idx].stars;
			headingid = headings[idx].id;
			index = idx;

			hedcsp = new Gtk.CssProvider();
			hedcss = ".xx { background: %s; color: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbbkg,sbsel);
			hedcsp.load_from_data(hedcss.data);
			nomcsp = new Gtk.CssProvider();
			nomcss = ".xx { background: %s; border-width: 0px; color: %s; }".printf(sbbkg,sbsel);
			nomcsp.load_from_data(nomcss.data);

			hbox = new Gtk.Box(HORIZONTAL,4);
			headinggrip = new Gtk.Box(HORIZONTAL,4);
			headinggrip.hexpand = true;
			headingdot = new Gtk.Label("●");
			headingdot.hexpand = false;
			headingdot.margin_start = 4;
			headingname = new Gtk.Entry();
			headingname.get_style_context().add_provider(nomcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
			headingname.get_style_context().add_class("xx");
			headingname.margin_start = 4;
			headingnamelayout = headingname.create_pango_layout(null);
			headingname.changed.connect(() => {
				if (doup) {
					int hh = getheadingindexbyid(headingid);
					if (hh >= 0) {
						doup = false;
						if (headingname.text.strip() != "") {
							headings[hh].name = headingname.text.strip();
							headingnamelayout.set_text(headings[hh].name, -1);
							int pw, ph = 0;
							headingnamelayout.get_pixel_size(out pw, out ph);
							headingname.width_request = pw + 30;
						}
						doup = true;
					}
				}
			});
			print("HEADINGBOX:\tmaking heading priority ui...\n");
			headingprioritybutton = new Gtk.MenuButton();
			headingprioritybutton.set_label("");
			headingprioritybutton.set_always_show_arrow(false);
			headingprioritybutton.set_icon_name("zoom-original");
			headingprioritypop = new Gtk.Popover();
			headingprioritypopbox = new Gtk.Box(VERTICAL,0);
			headingprioritypopscroll = new Gtk.ScrolledWindow();
			headingprioritypopbox.margin_top = 2;
			headingprioritypopbox.margin_end = 2;
			headingprioritypopbox.margin_start = 2;
			headingprioritypopbox.margin_bottom = 2;
			headingprioritypopscroll.set_child(headingprioritypopbox);
			headingprioritypop.set_child(headingprioritypopscroll);
			headingprioritypop.width_request = 160;
			headingprioritypop.height_request = 240;
			headingprioritybutton.popover = headingprioritypop;
			headingprioritybuttonclick = new Gtk.GestureClick();
			headingprioritybutton.add_controller(headingprioritybuttonclick);
			headingprioritypop.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingprioritypop.get_first_child().get_style_context().add_class("xx");
			headingprioritybutton.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingprioritybutton.get_first_child().get_style_context().add_class("xx");
			headingprioritybuttonclick.pressed.connect(() => {
				if (todos.length > 0) {
					if (doup) {
						doup = false;
						while (headingprioritypopbox.get_first_child() != null) {
							headingprioritypopbox.remove(headingprioritypopbox.get_first_child());
						}
						for(int p = 0; p < priorities.length; p++) {
							Gtk.Button tduh = new Gtk.Button.with_label(priorities[p].name);
							tduh.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
							tduh.get_style_context().add_class("xx");
							headingprioritypopbox.append(tduh);
							tduh.clicked.connect((nuh) => {
								uint tdx = findpriorityidbyname(nuh.label, priorities);
								if (tdx != -1) { 
									headings[idx].priority = tdx;
									addheadertoprioritiesbyindex(findpriorityindexbyname(nuh.label,priorities),headings[idx].id);
									headingprioritybutton.set_label(nuh.label);
								} else { print("%s doesn't match any priority names...\n",nuh.label); }
								headingprioritypop.popdown();
							});
						}
						doup = true;
					}
				}
			});
			print("HEADINGBOX:\tmaking heading todo ui...\n");
			headingtodobutton = new Gtk.MenuButton();
			headingtodobutton.set_label("");
			headingtodobutton.set_always_show_arrow(false);
			headingtodobutton.set_icon_name("object-select");
			headingtodopop = new Gtk.Popover();
			headingtodopopbox = new Gtk.Box(VERTICAL,0);
			headingtodopopscroll = new Gtk.ScrolledWindow();
			headingtodopopbox.margin_top = 2;
			headingtodopopbox.margin_end = 2;
			headingtodopopbox.margin_start = 2;
			headingtodopopbox.margin_bottom = 2;
			headingtodopopscroll.set_child(headingtodopopbox);
			headingtodopop.set_child(headingtodopopscroll);
			headingtodopop.width_request = 160;
			headingtodopop.height_request = 240;
			headingtodobutton.popover = headingtodopop;
			headingtodobuttonclick = new Gtk.GestureClick();
			headingtodobutton.add_controller(headingtodobuttonclick);
			headingtodopop.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingtodopop.get_first_child().get_style_context().add_class("xx");
			headingtodobutton.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingtodobutton.get_first_child().get_style_context().add_class("xx");
			headingtodobuttonclick.pressed.connect(() => {
				if (todos.length > 0) {
					if (doup) {
						doup = false;
						while (headingtodopopbox.get_first_child() != null) {
							headingtodopopbox.remove(headingtodopopbox.get_first_child());
						}
						for(int t = 0; t < todos.length; t++) {
							Gtk.Button pduh = new Gtk.Button.with_label(todos[t].name);
							pduh.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
							pduh.get_style_context().add_class("xx");
							headingtodopopbox.append(pduh);
							pduh.clicked.connect((nuh) => {
								uint tdx = findtodoidbyname(nuh.label, todos);
								if (tdx != -1) { 
									headings[idx].todo = tdx;
									addheadertotodosbyindex(findtodoindexbyname(nuh.label,todos),headings[idx].id);
									headingtodobutton.set_label(nuh.label);
								} else { print("%s doesn't match any todo names...\n",nuh.label); }
								headingtodopop.popdown();
							});
						}
						doup = true;
					}
				}
			});
			print("HEADINGBOX:\tmaking heading tag ui...\n");
			headingtaglist = new Gtk.Label("");
			headingtaglist.get_first_child().get_style_context().add_provider(lblcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingtaglist.get_first_child().get_style_context().add_class("xx");
			headingtagbutton = new Gtk.MenuButton();
			headingtagbutton.set_label("");
			headingtagbutton.set_always_show_arrow(false);
			headingtagbutton.set_icon_name("preferences-desktop-locale");
			headingtagpop = new Gtk.Popover();
			headingtagpopbox = new Gtk.Box(VERTICAL,0);
			headingtagpopscroll = new Gtk.ScrolledWindow();
			headingtagpopbox.margin_top = 2;
			headingtagpopbox.margin_end = 2;
			headingtagpopbox.margin_start = 2;
			headingtagpopbox.margin_bottom = 2;
			headingtagpopscroll.set_child(headingtagpopbox);
			headingtagpop.set_child(headingtagpopscroll);
// TAG: adapt size to content
			headingtagpop.width_request = 160;
			headingtagpop.height_request = 240;
			headingtagbutton.popover = headingtagpop;
			headingtagbuttonclick = new Gtk.GestureClick();
			headingtagbutton.add_controller(headingtagbuttonclick);
			headingtagpop.get_first_child().get_style_context().add_provider(popcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingtagpop.get_first_child().get_style_context().add_class("xx");
			headingtagbutton.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingtagbutton.get_first_child().get_style_context().add_class("xx");
			print("HEADINGBOX:\tmaking heading tag.pressed fn...\n");
			headingtagbuttonclick.pressed.connect(() => {
				if (tags.length > 0) {
					if (doup) {
						doup = false;
						while (headingtagpopbox.get_first_child() != null) {
							headingtagpopbox.remove(headingtagpopbox.get_first_child());
						}
						for(int t = 0; t < tags.length; t++) {
							Gtk.Button pduh = new Gtk.Button.with_label(tags[t].name);
							pduh.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
							pduh.get_style_context().add_class("xx");
							headingtagpopbox.append(pduh);
							pduh.clicked.connect((nuh) => {
								uint tdx = findtagidbyname(nuh.label, tags);
								if (tdx != -1) { 
									toggleheadertagbyindex(idx,findtagidbyname(nuh.label, tags));
									addheadertotagsbyindex(findtagindexbyname(nuh.label,tags),idx);
									string[] htaglist = {};
									for (int g = 0; g < headings[idx].tags.length; g++) {
										string gn = findtagnamebyid(headings[idx].tags[g], tags);
										if (gn.length > 0) { htaglist += gn; }
									}
									headingtaglist.set_text("");
									if (htaglist.length > 0) {
										headingtaglist.set_text(":%s:".printf(string.joinv(":",htaglist)));
									}
								} else { print("%s doesn't match any tag names...\n",nuh.label); }
								headingtagpop.popdown();
							});
						}
						doup = true;
					}
				}
			});
			headingexpander = new Gtk.ToggleButton();
			headingexpander.icon_name = "go-down";
			headingexpander.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			headingexpander.get_style_context().add_class("xx");
			headingexpander.toggled.connect(() => {
				if (headingexpander.active) {
					headingexpander.icon_name = "go-up";
				} else {
					headingexpander.icon_name = "go-down";
				}
			});
			print("HEADINGBOX:\tassembling ui...\n");
			hbox.append(headingdot);
			hbox.append(headingname);
			hbox.append(headinggrip);
			hbox.append(headingtaglist);
			hbox.append(headingtagbutton);
			hbox.append(headingtodobutton);
			hbox.append(headingprioritybutton);
			hbox.append(headingexpander);
			hbox.margin_top = 4;
			hbox.margin_start = 4;
			hbox.margin_end = 4;
			hbox.margin_bottom = 4;
			headingname.text = headings[idx].name;
			headingnamelayout.set_text(headings[idx].name, -1);
			int pxw, pxh = 0;
			headingnamelayout.get_pixel_size(out pxw, out pxh);
			headingname.width_request = pxw + 30;
			this.margin_top = 2;
			this.margin_start = (30 * (stars - 1)) + 10;
			this.margin_end = 40;
			this.margin_bottom = 2;

			this.get_style_context().add_provider(hedcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.append(hbox);
			thisclick = new Gtk.GestureClick();
			this.add_controller(thisclick);
			thisclick.pressed.connect(() => {
				print("HEADINGBOX: setting selection css...\n");
				for (int h = 0; h < headingboxes.length; h++) {
					if (headingboxes[h].headingid == this.headingid) {
						headingboxes[h].hedcss = ".xx { background: %s; color: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbhil,sbsel);
						headingboxes[h].nomcss = ".xx { background: %s; border-width: 0px; color: %s; }".printf(sbhil,sbsel);
					} else {
						headingboxes[h].hedcss = ".xx { background: %s; color: %s; box-shadow: 2px 2px 2px #00000066; }".printf(sbbkg,sbsel);
						headingboxes[h].nomcss = ".xx { background: %s; border-width: 0px; color: %s; }".printf(sbbkg,sbsel);
					}
					//print("HEADINGBOX: applying headingboxes[%d] hedcsp css: %s\n",h,headingboxes[h].hedcss);
					headingboxes[h].hedcsp.load_from_data(headingboxes[h].hedcss.data);
					//print("HEADINGBOX: applying headingboxes[%d] nomcsp css: %s\n",h,headingboxes[h].nomcss);
					headingboxes[h].nomcsp.load_from_data(headingboxes[h].nomcss.data);
				}
				if (headingid >= 0) {
					sel = headingid;
					hidx = index;
					print("HEADINGBOX: selected headings[%d] %s...\n",hidx,headings[hidx].name);
// check pannelboxes for parameter panes, update them if not pinned...
// ModalBox/box(content)/ParamBox
// vdiv/ModalBox/content/Outliner/outlinerscroll/outlinerscrollbox/this
//   6      5        4       3          2               1         
					for (int m = 0; m < modeboxes.length; m++) {
						//print("HEADINGBOX: checking modeboxes[%d].contenttype: %s\n",m,modeboxes[m].contenttype);
						if (modeboxes[m].contenttype == "parambox") {
							modeboxes[m].content.remove(modeboxes[m].content.get_first_child());
							modeboxes[m].content.append(new ParamBox(modeboxes[m].id));
						}
					}
				}
			});
		}
		print("HEADINGBOX: ended.\n");
	}
}

public class ParamBox : Gtk.Box {
	private Gtk.Box pbox;
	private Gtk.ScrolledWindow pscroll;
	private HeadingBox heb;
	public string type;
	public uint owner;
	public string name;
	private ElementBox elm;
	private string pbxcss;
	private Gtk.CssProvider pbxcsp;

	public ParamBox(uint o) {
		print("PARAMBOX: created...\n");
		owner = o;
		type = "parambox";
		this.name = "%s_elements".printf(headings[hidx].name);
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.vexpand = true;
		this.hexpand = true;
		pbxcsp = new Gtk.CssProvider();
		pbxcss = ".xx { background: %s; }".printf(sbshd);
		pbxcsp.load_from_data(pbxcss.data);
		this.get_style_context().add_provider(pbxcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		this.get_style_context().add_class("xx");
		if (headings[hidx].elements.length > 0) {
			print("PARAMBOX: adding pbox and pscroll...\n");
			pscroll = new Gtk.ScrolledWindow();
			pbox = new Gtk.Box(VERTICAL,4);
			pbox.hexpand = true;
			pbox.vexpand = true;
			pscroll.set_propagate_natural_height(true);
			print("PARAMBOX: heading[%d] = %s\n",hidx,headings[hidx].name);
			for (int e = 0; e < headings[hidx].elements.length; e++) {
				print("PARAMBOX: checking element %s for type....\n",headings[hidx].elements[e].name);
				elm = new ElementBox(headings[hidx].elements[e].index,headings[hidx].elements[e].type);
				pbox.append(elm);
			}
			pbox.get_style_context().add_provider(pbxcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
			pbox.get_style_context().add_class("xx");
			pscroll.set_child(pbox);
			this.append(pscroll);
		} else { print("PARAMBOX: nothing to do here...\n"); }
		print("PARAMBOX: create ended.\n");
	}
}

public class ModalBox : Gtk.Box {
	public Gtk.Box content;
	private Gtk.Box control;
	private Gtk.Box typelistpopbox;
	private Gtk.Popover typelistpop;
	private Gtk.MenuButton typelistbutton;
	private Gtk.ScrolledWindow typpopscroll;
	private Gtk.GestureClick typelistclick;
	private Gtk.CssProvider ctrcsp;
	private string ctrcss;
	private Gtk.CssProvider concsp;
	private string concss;
	private string butcss;
	private Gtk.CssProvider butcsp;
	private Gtk.Box modalboxexpander;
	public string contenttype;
	public Gtk.Box modalboxpanectrl;
	public uint id;
	public int index;
	public ModalBox (int typ, int idx) {
		print("MODALBOX: created (typ %d, idx %d)\n",typ,idx);
		index = idx;
// typ 0 = outliner
// typ 1 = parameters
// typ 2 = nodegraph
// typ 3 = processgraph
// typ 4 = timeline
		switch (typ) {
			case 0: this.contenttype = "outliner"; break;
			case 1: this.contenttype = "parambox"; break;
			case 2: this.contenttype = "nodegraph"; break;
			case 3: this.contenttype = "processgraph"; break;
			case 4: this.contenttype = "timeline"; break;
			default: this.contenttype = "unknown"; break;
		}
		id = makemeahash(contenttype,index);
		this.set_orientation(VERTICAL);
		this.spacing = 0;
		this.vexpand = false;
		content = new Gtk.Box(VERTICAL,0);
		control = new Gtk.Box(HORIZONTAL,0);
		content.vexpand = true;
		control.hexpand = false;

		content.margin_top = 0;
		content.margin_end = 0;
		content.margin_start = 0;
		content.margin_bottom = 0;

		control.margin_top = 0;
		control.margin_end = 0;
		control.margin_start = 0;
		control.margin_bottom = 0;

		ctrcsp = new Gtk.CssProvider();
		ctrcss = ".xx { background: %s; }".printf(sbshd);
		ctrcsp.load_from_data(ctrcss.data);
		control.get_style_context().add_provider(ctrcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		control.get_style_context().add_class("xx");

		concsp = new Gtk.CssProvider();
		concss = ".xx { background: %s; }".printf(sbbkg);
		concsp.load_from_data(concss.data);
		content.get_style_context().add_provider(concsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		content.get_style_context().add_class("xx");

		typelistbutton = new Gtk.MenuButton();
		typelistpop = new Gtk.Popover();
		typelistpopbox = new Gtk.Box(VERTICAL,2);
		typpopscroll = new Gtk.ScrolledWindow();

		foreach (string s in paneltypes) {
			Gtk.Button muh = new Gtk.Button.with_label (s);
			muh.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			muh.get_style_context().add_class("xx");
			typelistpopbox.append(muh);
			muh.clicked.connect ((buh) => {
				if (buh.label == "Parameters") {
					this.contenttype = "parambox";
					content.remove(content.get_first_child());
					print("MODALBOX: adding parameter pane to content...\n");
					content.append(new ParamBox(id));
					typelistpop.popdown();
				}
				if (buh.label == "Outliner") {
					this.contenttype = "outliner";
					content.remove(content.get_first_child());
					print("MODALBOX: adding outliner pane to content...\n");
					content.append(new Outliner(hidx,id));
					typelistpop.popdown();
				}
			});
		}
		typelistbutton.icon_name = "preferences-desktop-display";
		typelistpopbox.margin_top = 0;
		typelistpopbox.margin_end = 0;
		typelistpopbox.margin_start = 0;
		typelistpopbox.margin_bottom = 0;
		typpopscroll.set_child(typelistpopbox);
		typelistpop.width_request = 200;
		typelistpop.height_request = 220;
		typelistpop.set_child(typpopscroll);
		typelistbutton.popover = typelistpop;
		typelistpop.set_position(TOP);
		typelistclick = new Gtk.GestureClick();
		typelistbutton.add_controller(typelistclick);
		typelistclick.pressed.connect(() => {
			print("typelist selected\n");
		});

		typelistpop.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		typelistpop.get_first_child().get_style_context().add_class("xx");
		typelistbutton.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		typelistbutton.get_first_child().get_style_context().add_class("xx");

		modalboxpanectrl = new Gtk.Box(HORIZONTAL,0);
		modalboxexpander = new Gtk.Box(HORIZONTAL,0);
		modalboxexpander.hexpand = true;
		control.append(modalboxpanectrl);
		control.append(modalboxexpander);
		control.append(typelistbutton);
		this.margin_top = 0;
		this.margin_end = 0;
		this.margin_start = 0;
		this.margin_bottom = 0;
		this.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		this.get_style_context().add_class("xx");
		this.append(content);
		this.append(control);
	}
}


public class frownwin : Gtk.ApplicationWindow {
	private bool amdesktop;
	private bool amphone;
	private int winx;
	private int winy;
	public frownwin (Gtk.Application frownedupon) {Object (application: frownedupon);}
	construct {

		paneltypes = {"Outliner", "Parameters", "NodeGraph", "ProcessGraph", "TimeLine"};

// named colors

		string pagebg = "#6B3521FF";		// zn orange
		string pagefg = "#BD4317FF";
		string artcbg = "#112633FF";		// sb blue
		string artcfg = "#1A3B4FFF";

		string bod_hi = "#5FA619FF";		// green
		string bod_lo = "#364F1DFF";

		string tal_hi = "#14A650FF";		// turqoise
		string tal_lo = "#1D5233FF";

		sbbkg = "#112633";	// sb blue
		sbsel = "#50B5F2";	// selection/text
		sblin = "#08131A";	// dark lines
		sblit = "#19394D";	// sbbkg + 10
		sbhil = "#1D4259";	// sbbkg + 5
		sblow = "#153040";	// sbbkg - 5
		sbshd = "#0C1D26";	// sbbkg - 10
		sbent = "#0E232E";	// sbbkg - 12

		string out_hi = "#8738A1FF";		// purple
		string out_lo = "#351C3DFF";

// css

		popcsp = new Gtk.CssProvider();
		string popcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblin,sbbkg,sbsel);
		popcsp.load_from_data(popcss.data);

		butcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblin,sblit,sbsel);
		butcsp = new Gtk.CssProvider();
		butcsp.load_from_data(butcss.data);

		entcsp = new Gtk.CssProvider();
		entcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblin,sbhil,sbsel);
		entcsp.load_from_data(entcss.data);

		lblcsp = new Gtk.CssProvider();
		lblcss = ".xx { color: %s; }".printf(sbsel);
		lblcsp.load_from_data(lblcss.data);

// interaction states

		int winx = 0;
		int winy = 0;
		doup = false;

// graph memory


// window

		this.title = "frownedupon";
		this.close_request.connect((e) => { return false; });

// header

		Gtk.Label titlelabel = new Gtk.Label("frownedupon");
		Gtk.HeaderBar iobar = new Gtk.HeaderBar();
		iobar.show_title_buttons = false;
		iobar.set_title_widget(titlelabel);
		this.set_titlebar(iobar);
		this.set_default_size(360, (720 - 46));

		Gtk.CssProvider hedcsp = new Gtk.CssProvider();
		string hedcss = ".xx { border-radius: 0; border-color: %s; background: %s; color: %s; }".printf(sblin,sblow,sbsel);
		hedcsp.load_from_data(hedcss.data);
		iobar.get_style_context().add_provider(hedcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		iobar.get_style_context().add_class("xx");
	
// headerbr buttons

		Gtk.MenuButton savemenu = new Gtk.MenuButton();
		Gtk.MenuButton loadmenu = new Gtk.MenuButton();
		savemenu.icon_name = "document-save-symbolic";
		loadmenu.icon_name = "document-open-symbolic";

		savemenu.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		savemenu.get_first_child().get_style_context().add_class("xx");
		loadmenu.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		loadmenu.get_first_child().get_style_context().add_class("xx");

		Gtk.GestureClick loadmenuclick = new Gtk.GestureClick();
		loadmenu.add_controller(loadmenuclick);


		Gtk.Button savebutton = new Gtk.Button.with_label("save");
		Gtk.Popover savepop = new Gtk.Popover();
		Gtk.Popover loadpop = new Gtk.Popover();
		Gtk.Box savepopbox = new Gtk.Box(VERTICAL,0);
		Gtk.Box loadpopbox = new Gtk.Box(VERTICAL,0);
		savepopbox.margin_end = 2;
		savepopbox.margin_top = 2;
		savepopbox.margin_start = 2;
		savepopbox.margin_bottom = 2;
		loadpopbox.margin_end = 2;
		loadpopbox.margin_top = 2;
		loadpopbox.margin_start = 2;
		loadpopbox.margin_bottom = 2;
		saveentry = new Gtk.Entry();
		saveentry.text = "default";
		savepopbox.append(saveentry);
		savepopbox.append(savebutton);
		savepop.set_child(savepopbox);
		loadpop.set_child(loadpopbox);
		savemenu.popover = savepop;
		loadmenu.popover = loadpop;
		iobar.pack_start(loadmenu);
		iobar.pack_end(savemenu);



		savepop.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		savepop.get_first_child().get_style_context().add_class("xx");
		loadpop.get_first_child().get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
		loadpop.get_first_child().get_style_context().add_class("xx");

// load

		loadmenuclick.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (loadpopbox.get_first_child() != null) {
					loadpopbox.remove(loadpopbox.get_first_child());
				}
				print("LOAD: button pressed...\n");
				var pth = GLib.Environment.get_current_dir();
				bool allgood = true;
				GLib.Dir dcr = null;
				try { dcr = Dir.open (pth, 0); } catch (Error e) { print("%s\n",e.message); allgood = false; }
				if (allgood) {
					string? name = null;
					print("LOAD: searching for org files in %s\n",((string) pth));
					while ((name = dcr.read_name ()) != null) {
						var exts = name.split(".");
						if (exts.length == 2) {
							print("LOAD:\tchecking file: %s\n", name);
							if (exts[1] == "org") {
								Gtk.Button muh = new Gtk.Button.with_label (name);
								muh.get_style_context().add_provider(butcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
								muh.get_style_context().add_class("xx");
								loadpopbox.append(muh);
								muh.clicked.connect ((buh) => {
									if (buh.label.strip() != "") {
										print("LOAD:\t\tloading %s...\n",buh.label);
										loadmemyorg(buh.label.strip());
										if (headings.length > 0) {
											hidx = 0;
											restartui(0);
										} else { print("LOAD: failed to load any headings...\n"); }
									} else { print("LOAD: nothing to load, aborting.\n"); }
									loadpop.popdown();
								});
							}
						}
					}
				}
				doup = true;
			}			
		});

// initial containers

		ModalBox panea = new ModalBox(0,0);
		ModalBox paneb = new ModalBox(1,1);
		modeboxes += panea;
		modeboxes += paneb;

// toplevel ui

		vdiv = new Gtk.Paned(VERTICAL);
		vdiv.start_child = modeboxes[0];
		vdiv.end_child = modeboxes[1];
		vdiv.wide_handle = true;
		vdiv.set_shrink_end_child(false);
		var fch = (Gtk.Widget) vdiv.get_start_child();
		var sep = (Gtk.Widget) fch.get_next_sibling();

// add to window

		this.set_child(vdiv);
		vdiv.position = 600;

		doup = true;

//////////////////////////////////////////////////////////////////////////////////////////////
///////////`                  //`     ///////` //`      //`     //////`                 /////
//////////        ///////    //      ///////  //       //      //////     //////       /////  
/////////        /////////////       `   //           //      //////     /////        /////  
////////        /////////////      ///////////`      //      //////          `       /////  
////////        `         //      ///////////       //      //////                 //////  
/////////////////////`   //      ///////////       //      //////      /////////////////   
////////////  //////    //      ///  // ///       //      /// //      ////  ///////////    
///////////        `   //           //    `      //          //       `    ///////////      
/////////////////////////////////////////////////////////////////////////////////////         
                                                                                           
//		sbbkg = "#112633";	// sb blue
//		sbsel = "#50B5F2";	// selection/text
//		sblin = "#08131A";	// dark lines
//		sblit = "#19394D";	// sbbkg + 10
//		sbhil = "#1D4259";	// sbbkg + 5
//		sblow = "#153040";	// sbbkg - 5
//		sbshd = "#0C1D26";	// sbbkg - 10
//		sbent = "#0E232E";	// sbbkg - 12

		Gtk.CssProvider pcsp = new Gtk.CssProvider();
		string pcss = ".wide { min-width: 20px; min-height: 20px; border-width: 4px; border-color: %s; border-style: solid; background: repeating-linear-gradient( -45deg, %s, %s 4px, %s 5px, %s 9px);}".printf(sbbkg,sbshd,sbshd,sbbkg,sbbkg);
		pcsp.load_from_data(pcss.data);
		sep.get_style_context().add_provider(pcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		sep.get_style_context().add_class("wide");


// initialize

// events
		this.notify.connect(() => {
			int wx, wy = 0;
			this.get_default_size(out wx, out wy);
			if (wx != winx || wy != winy) {
				winx = wx; winy = wy;
				if ((wx > 720) && (wx > wy)) {
					if (amdesktop == false) {
						if (vdiv.get_orientation() == VERTICAL) {
							print("window size is %dx%d\n",wx,wy);
							amdesktop = true; amphone = false;
							vdiv.set_orientation(HORIZONTAL);
							vdiv.position = (wx - 400);
						}
					}
				}
				if ((wx < 720) && (wx < wy)) {
					if (amphone == false) {
						if (vdiv.get_orientation() == HORIZONTAL) {
							amphone = true; amdesktop = false;
							vdiv.set_orientation(VERTICAL);
							vdiv.position = (wy - 65);
						}
					}
				}
			}
		});
// graph interaction


///////////////////////////////
//                           //
//    node graph rendering   //
//                           //
///////////////////////////////
	}
}



int main (string[] args) {
	var app = new frownedupon();
	app.activate.connect (() => {
		var win = new frownwin(app);
		win.present ();
	});
	return app.run (args);
}