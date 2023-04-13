// frownedupon
// org-compatible branchng script queue
// by c.p.brown 2023
//
// status: replacing pointers with brute force search...


using GLib;

// data.

struct output {
	uint id;
	string name;
	string value;
	uint owner;
}
struct input {
	uint id;
	string name;
	uint source;
	string value;
	string defaultv;
	string org;
	uint owner;
}
struct param {
	string name;
	string value;
	uint owner;
}
struct element {
	string			name;			// can be whatever, but try to autoname to be unique
	uint			id;			// hash of name + iterator + time
	string			type;			// used for ui, writing back to org
	input[]		inputs;		// can take input wires
	output[]		outputs;		// can be wired out
	param[]		params;		// local params; no wiring
	uint			owner;			// 
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
	int			stars;			// indentation
	uint			priority;		// id of priority, one per heading
	uint			todo;			// id of todo, one per heading
	uint[]			tags;			// id[] of tags, many per heading
	uint			template;		// internal use only: template id
	param[]		params;		// internal use only: fold, visible, positions 
	element[]		elements;		// elements under this heading, might be broken out into flat lists later
	string			nutsack;		// misc stuff found under the headigng that wasn't captured as elements 
}
// globals
// avoid dicking-around with refs, owned, unowned and other limitations

string[]		lines;			// the lines of an orgfile
string			srcblock;
string[]		hvars;			// header vars
string			headingname;
heading[]		headings;		// all headers for the orgfile
element[]		elements;
param[]		params;
input[]		inputs;
output[]		outputs;
int			thisheading;	// index of current heading
int[]			typecount;		// used for naming: 0 paragraph, 1 propdrawer, 2 srcblock, 3, example, 4 table, 5 command, 6 nametag
bool			spew;			// print
bool			hard;			// print more
tag[]			tags;
priority[]		priorities;
todo[]			todos;
bool			doup;			// block ui events
uint			sel;			// selected item (fixed)
int			hidx;			// header list index of selected item (volatile)
string[]		paneltypes;
Gtk.Entry		saveentry;		// save file feeld
Gtk.Paned		vdiv;			// needed for reflow, resize, etc.

int imod (int a, int b) {
	if (a >= 0) { return (a % b); }
	if (a >= -b) { return (a + b); }
	return ((a % b) + b) % b;
}

// 'linking' stuff, since we're nod doing refs anymore...

string getmysourcevalbyid (uint s) {
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int o = 0; o < headings[h].elements[e].outputs.length; o++) {
				if (headings[h].elements[e].outputs[o].id == s) { 
					if (headings[h].elements[e].outputs[o].value != null) {
						return headings[h].elements[e].outputs[o].value; 
					}
				}
			}
		}
	}
	return "";
}

uint getmysourceidbyname (string n) {
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int o = 0; o < headings[h].elements[e].outputs.length; o++) {
				if (headings[h].elements[e].outputs[o].name == n) { 
					return headings[h].elements[e].outputs[o].id; 
				}
			}
		}
	}
	return 0;
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

void crosslinkeverything () {
	for (int h = 0; h < headings.length; h++) {
		for (int e = 0; e < headings[h].elements.length; e++) {
			for (int i = 0; i < headings[h].elements[e].inputs.length; i++) {
				if (headings[h].elements[e].inputs[i].name != null) { 
					if (headings[h].elements[e].inputs[i].name != "") { 
						uint myo = getmysourceidbyname(headings[h].elements[e].inputs[i].name);
						if (myo != 0) {
							headings[h].elements[e].inputs[i].source = myo;
						}
					}
				}
			}
		}
	}
}

int findtodobyname (string n, todo[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

int findpribyname (string n, priority[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

int findtagbyname (string n, tag[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q].name == n) { return q; }
	}
	return h.length;
}

bool notinuintarray (uint n, uint[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q] == n) { return false; }
	}
	return true;
}

bool notinstringarray (string n, string[] h) {
	for (int q = 0; q < h.length; q++) {
		if (h[q] == n) { return false; }
	}
	return true;
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

uint makemeahash(string n, int t) {
	//DateTime dd = new DateTime.now_local();
	//print("MAKEMEAHASH: hashing %s_%d_%lld ...\n",n,t,GLib.get_real_time());
	return "%s_%d_%lld".printf(n,t,GLib.get_real_time()).hash();
}

/* TODO:
uint[] evalpath (uint[] nn, uint me) {
	bool allgood = true;
	int r = 0;
	while (r < nn.length) {
		for (int f = 0; f < nn.length; f++) {
			for (int h = 0; h < headings.length; n++) {
				if (nodes[n].id == nn[f]) {
					for(int i = 0; i < nodes[n].input.length; i++) {
						nn += nodes[n].input[i];
					}
				}
			}
			r += 1;
		}
		if (r > 10) { break; }
	}
	uint[] ee = {};
	for (int n = (nn.length - 1); n >= 0; n--) {
		allgood = true;
		for (int e = 0; e < ee.length; e++) {
			if (ee[e] == nn[n]) { allgood = false; break; }
		}
		if (allgood) { ee += nn[n]; }
	}
	for (int j = 0; j < ee.length; j++) { print("ee[%d] = %u\n",j,ee[j]); }
	return ee;
}
*/

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
			pp.name = ee.name.concat("_verbatimtext");
			pp.id = makemeahash(ee.name, c);
			pp.value = string.joinv("\n",txt);
			ee.outputs += pp;
			typecount[3] += 1;
			ee.owner = headings[thisheading].id;
			headings[thisheading].elements += ee;
			if (spew) { print("[%d]%s\tsuccessfully captured verbatim text\n",c,tabs); }
			if (spew) { print("[%d]%sfindexample ended.\n",c,tabs); }
			int64 xtte = GLib.get_real_time();
			if (spew) { print("\nfind example took %f microseconds\n\n",((double) (xtte - xtts)));}
			return c;
		}
	}
	if (spew) { print("[%d]%sfindexample found nothing.\n",l,tabs); }
	int64 xtte = GLib.get_real_time();
	if (spew) { print("\nfind example took %f microseconds\n\n",((double) (xtte - xtts)));}
	return l;
}

// TODO: check foreign language
int findparagraph (int l, int ind) {
	int64 phtts = GLib.get_real_time();
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	if (spew) { print("[%d]%sfindparagraph started...\n",l,tabs); }
	if (spew) { print("[%d]%sheadings[%d].name = %s\n",l,tabs,thisheading,headings[thisheading].name); }
	if (spew) { print("[%d]%sheadings[%d].id = %u\n",l,tabs,thisheading,headings[thisheading].id); }
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
		element ee = element();
		ee.name = txtname;
		ee.id = makemeahash(ee.name,c);
		ee.type = "paragraph";
		output pp = output();
		//pp.target = null;
		pp.name = ee.name.concat("_text");
		pp.id = makemeahash(ee.name, c);
		pp.value = string.joinv("\n",txt);
		pp.owner = ee.id;
		ee.outputs += pp;
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
								qq.owner = ee.id;
								ee.inputs += qq;
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
		if (spew) { print("[%d]%s\tcapturing owner id: %u\n",c,tabs,headings[thisheading].id); }
		ee.owner = headings[thisheading].id;
		if (spew) { print("[%d]%s\tcapturing element: %s\n",c,tabs,ee.name); }
		headings[thisheading].elements += ee;
		typecount[0] += 1;
		if (spew) { print("[%d]%s\tsuccessfully captured plain text\n",c,tabs); }
		if (spew) { print("[%d]%sfindparagraph ended.\n",c,tabs); }
		int64 phtte = GLib.get_real_time();
		if (spew) { print("\nfind paragraph took %f microseconds\n\n",((double) (phtte - phtts)));}
		return c;
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
							if (notinstringarray(lsp[m].strip(),themaths)) {
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
					oo.name = tablename.concat("_spreadsheet");
					oo.id = makemeahash(oo.name,(tln+rc));
					oo.value = csv;
					oo.owner = ee.id;
					ee.outputs += oo;
					if (themaths.length > 0) {
						string fml = string.joinv("\n",themaths);
						param ii = param();
						ii.name = tablename.concat("_formulae");
						ii.value = fml;
						if (themathvars.length > 0 && themathvars.length == themathorgvars.length) {
							for(int x = 0; x < themathvars.length; x++) {
								input ff = input();
								ff.name = themathvars[x];
								ff.id = makemeahash(ff.name,f);

// org-sbe vals need to be obtained after an eval
// so we just store its org syntax for now
								ff.org = themathorgvars[x];
								ff.owner = ee.id;
								ee.inputs+= ff;
							}
						}
						ii.owner = ee.id;
						ee.params += ii;
						t = f;
					}
// move carrot to next line after table block, search up to 10 lines forward...
					for (f = t; f < (t + 10); f++) {
						if (lines[t].strip().has_prefix("#+END_TABLE")){ t = (f + 1); break; }
					}
					typecount[4] += 1;
					ee.owner = headings[thisheading].id;
					headings[thisheading].elements += ee;
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
		cc.name = nwn.concat("_code");
		cc.value = src;
		cc.owner = ee.id;
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
					tt.name = "type";
					tt.value = hpt[1];
					tt.owner = ee.id;
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
							ip.name = hvars[p];								// name
							ip.id = makemeahash(ip.name, b);							// id, probably redundant
							ip.value = hvars[(p+1)];							// value - volatile
							ip.org = "%s=%s".printf(hvars[p],hvars[(p+1)]);	// org syntax
							ip.defaultv = hvars[(p+1)];						// fallback value
							ip.owner = ee.id;
							ee.inputs += ip;
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
							pp.name = o[p];			// name
							pp.value = o[(p+1)];		// value - volatile
							pp.owner = ee.id;
							ee.params += pp;
						} else { break; }
						p += 1;
					}
				}
			}
		}

// make placeholder output
		output rr = output();
		rr.name = nwn.concat("_result");
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
		rr.owner = ee.id;
		ee.outputs += rr;
		ee.owner = headings[thisheading].id;
		headings[thisheading].elements += ee;
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
					ee.owner = headings[thisheading].id;
					headings[thisheading].elements += ee;
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
					o.name = propparts[1].strip();
					o.value = propparts[2].strip();
					o.id = o.name.hash();
					o.owner = ee.id;
					ee.outputs += o;
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
					int ftdo = findtodobyname(tdon,todos);
					if (ftdo < todos.length) {
						aa.todo = todos[ftdo].id;
					}
					if (notinuintarray(aa.id,todos[ftdo].headings)) {
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
					int fpri = findpribyname(prn,priorities);
					if (fpri < priorities.length) {
						aa.priority = priorities[fpri].id;
					}
					if (notinuintarray(aa.id,priorities[fpri].headings)) {
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
								int ftag = findtagbyname(gpn,tags);
								if (ftag < tags.length) { 
									if (notinuintarray(tags[ftag].id, aa.tags)) {
										if (spew) { print("[%d]%s\t\t\tadding existing tag :%s: to heading: %s\n",l,tabs,tags[ftag].name,aa.name); }
										aa.tags += tags[ftag].id;
									}
									if (notinuintarray(aa.id, tags[ftag].headings)) {
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
		thisheading = (headings.length - 1);
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
			ee.id = ee.name.hash();
			ee.type = "nametag";
			output oo = output();
			oo.name = lsp[1];
			oo.id = oo.name.hash();
			oo.value = lsp[2];
			oo.owner = ee.id;
			ee.outputs += oo;
			ee.owner = headings[thisheading].id;
			headings[thisheading].elements += ee;
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
	if (thisheading >= 0) {
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
							n = findparagraph(n,ind);
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
			/*
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
			hidx = 0;
			*/
			thisheading = -1;
			print("loadmemyorg: headings.length   = %d\n",headings.length);
			print("loadmemyorg: elements.length   = %d\n",elements.length);
			print("loadmemyorg: params.length     = %d\n",params.length);
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
			int64 chxts = GLib.get_real_time();
			crosslinkeverything();
			int64 chxte = GLib.get_real_time();
			if (spew) { print("\nfind example took %f microseconds\n\n",((double) (chxte - chxts)));}
			if (headings.length > 0) { sel = headings[0].id; hidx = 0; }
			if (spew) { print("checking elements...\n"); }
			for (int h = 0; h < headings.length; h++) {
				print("heading %s has %d elements\n",headings[h].name,headings[h].elements.length);
				for (int e = 0; e < headings[h].elements.length; e++) {
					print("\t\telement %s is of type %s\n",headings[h].elements[e].name,headings[h].elements[e].type);
					print("\t\telement %s has %d inputs\n",headings[h].elements[e].name,headings[h].elements[e].inputs.length);
					print("\t\telement %s has %d outputs\n",headings[h].elements[e].name,headings[h].elements[e].outputs.length);
					print("\t\telement %s has %d params\n",headings[h].elements[e].name,headings[h].elements[e].params.length);
				} 
			}
		} else { print("Error: orgfile was empty.\n"); }
	} else { print("Error: couldn't find orgfile.\n"); }
}

void restartui(int ww) {
	ModalBox panea = new ModalBox(0);
	ModalBox paneb = new ModalBox(1);
	vdiv.get_first_child().destroy();
	vdiv.get_last_child().destroy();
	vdiv.start_child = panea;
	vdiv.end_child = paneb;
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
	private Gtk.Label outputvar;
	private Gtk.Box outputcontainer;
	private Gtk.Entry outputval;
	private Gtk.ToggleButton outputshowval;
	private string oupcss;
	private Gtk.CssProvider oupcsp;
	private string ouvcss;
	private Gtk.CssProvider ouvcsp;
	private Gtk.TextTagTable outputvaltextbufftags;
	private GtkSource.Buffer outputvaltextbuff;
	private GtkSource.View outputvaltext;
	private Gtk.ScrolledWindow outputvalscroll;
	private Gtk.Box outputscrollbox;
	private string evalmyparagraph(int h,int e,int o) {
		// para eval goes here
		string v = headings[h].elements[e].outputs[o].value;
		for (int i = 0; i < headings[h].elements[e].inputs.length; i++) {
			string k = headings[h].elements[e].inputs[i].defaultv;
			string n = getmysourcevalbyid(headings[h].elements[e].inputs[i].source);
			if (k != "" && n != "") {
				v = v.replace(k,n);
			}
		}
		return v;
	}
	public OutputRow (int e, int idx) {
		print("OUTPUTROW: started (%d, %d)\n",e,idx);
		if (idx < headings[hidx].elements[e].outputs.length) {
			outputvar = new Gtk.Label(null);
			outputvar.margin_start = 10;
			outputvar.set_text(headings[hidx].elements[e].outputs[idx].name);
			outputcontainer = new Gtk.Box(HORIZONTAL,10);

// one-liners
			if (headings[hidx].elements[e].type == "nametag" || headings[hidx].elements[e].type == "propdrawer") {
				outputval = new Gtk.Entry();
				outputval.set_text(headings[hidx].elements[e].outputs[idx].value);

// edit
				outputvaltext.buffer.changed.connect(() => {
					headings[hidx].elements[e].outputs[idx].value = outputval.buffer.text;
				});
				outputval.hexpand = true;
				outputcontainer.append(outputvar);
				outputcontainer.append(outputval);
			}

// editable multiline text outputs
			if (headings[hidx].elements[e].type == "paragraph" || headings[hidx].elements[e].type == "example") {
				outputscrollbox = new Gtk.Box(VERTICAL,10);
				outputvalscroll = new Gtk.ScrolledWindow();
				outputvalscroll.height_request = 200;
				outputvaltextbufftags = new Gtk.TextTagTable();
				outputvaltextbuff = new GtkSource.Buffer(outputvaltextbufftags);
				outputvaltext = new GtkSource.View.with_buffer(outputvaltextbuff);
				outputvaltext.buffer.set_text(headings[hidx].elements[e].outputs[idx].value);
				outputvaltext.accepts_tab = true;
				outputvaltext.set_monospace(true);
				outputvaltextbuff.set_highlight_syntax(true);

// edit
				outputvaltext.buffer.changed.connect(() => {
					headings[hidx].elements[e].outputs[idx].value = outputvaltext.buffer.text;
				});
				outputvalscroll.set_child(outputvaltext);
				outputscrollbox.append(outputvalscroll);
				outputscrollbox.vexpand = true;
				outputscrollbox.margin_top = 0;
				outputscrollbox.margin_end = 0;
				outputscrollbox.margin_start = 0;
				outputscrollbox.margin_bottom = 0;

// paragraph is a special case as it may require eval, but isn't a param that creates an output like srcblock...
				if (headings[hidx].elements[e].type != "paragraph") {
					outputshowval = new Gtk.ToggleButton();
					outputshowval.icon_name = "user-invisible";
					ouvcsp = new Gtk.CssProvider();
					ouvcss = ".xx { background: #00FFFF20; }";
					ouvcsp.load_from_data(ouvcss.data);
					outputvaltext.get_style_context().add_provider(ouvcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
					outputvaltext.get_style_context().add_class("xx");
					outputshowval.toggled.connect(() => {
						if (outputshowval.active) {
							string outval = evalmyparagraph(hidx,e,idx);
							outputvaltext.buffer.set_text("(%s)".printf(outval));
							outputshowval.icon_name = "user-available";
							ouvcss = ".xx { background: #FF000020; }"; ouvcsp.load_from_data(ouvcss.data);
						} else {
							outputvaltext.buffer.set_text(headings[hidx].elements[e].outputs[idx].value);
							ouvcss = ".xx { background: #00FFFF20; }"; ouvcsp.load_from_data(ouvcss.data);
							outputshowval.icon_name = "user-invisible";
						}
					});
					outputcontainer.append(outputshowval);
				}
				outputcontainer.append(outputscrollbox);
			}
			outputcontainer.vexpand = true;
			outputcontainer.margin_top = 4;
			outputcontainer.margin_start = 4;
			outputcontainer.margin_end = 4;
			outputcontainer.margin_bottom = 4;

// some elements can't edit outputs here
			if (headings[hidx].elements[e].type != "paragraph" && headings[hidx].elements[e].type != "table") {
				print("add output overrides here\n");
			}
			oupcsp = new Gtk.CssProvider();
			oupcss = ".xx { background: #FF101020; box-shadow: 2px 2px 2px #00000066; }";
			oupcsp.load_from_data(oupcss.data);
			this.get_style_context().add_provider(oupcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 10;
			this.margin_start = 10;
			this.margin_end = 10;
			this.margin_bottom = 10;
			this.append(outputcontainer);
		}
	}
}

public class InputRow : Gtk.Box {
	private Gtk.Label inputvar;
	private Gtk.Box inputcontainer;
	private Gtk.Entry inputdefvar;
	private Gtk.ToggleButton inputshowval;
	private string inpcss;
	private Gtk.CssProvider inpcsp;
	private string invcss;
	private Gtk.CssProvider invcsp;
	public InputRow (int e, int idx) {
		print("INPUTROW: started (%d, %d)\n",e,idx);
		if (idx < headings[hidx].elements[e].inputs.length) {
			inputvar = new Gtk.Label(null);
			inputvar.margin_start = 10;
			inputvar.set_text(headings[hidx].elements[e].inputs[idx].name);
			inputdefvar = new Gtk.Entry();
			inputdefvar.set_text(headings[hidx].elements[e].inputs[idx].defaultv);
			inputdefvar.hexpand = true;
			inputshowval = new Gtk.ToggleButton();
			inputshowval.icon_name = "user-invisible";
			invcsp = new Gtk.CssProvider();
			invcss = ".xx { background: #00FFFF20; }";
			invcsp.load_from_data(invcss.data);
			inputdefvar.get_style_context().add_provider(invcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			inputdefvar.get_style_context().add_class("xx");
			inputshowval.toggled.connect(() => {
				if (inputshowval.active) {
					string inval = getmysourcevalbyid(headings[hidx].elements[e].inputs[idx].source);
					inputdefvar.set_text("(%s)".printf(inval));
					inputshowval.icon_name = "user-available";
					invcss = ".xx { background: #FF000020; }"; invcsp.load_from_data(invcss.data);
				} else {
					inputdefvar.set_text(headings[hidx].elements[e].inputs[idx].defaultv);
					invcss = ".xx { background: #00FFFF20; }"; invcsp.load_from_data(invcss.data);
					inputshowval.icon_name = "user-invisible";
				}
			});
			print("INPUTROW:\tinput label: %s\n",inputvar.get_text());
			inputcontainer = new Gtk.Box(HORIZONTAL,10);
			inputcontainer.append(inputvar);
			inputcontainer.append(inputdefvar);
			inputcontainer.append(inputshowval);
			inputcontainer.vexpand = true;
			inputcontainer.margin_top = 4;
			inputcontainer.margin_start = 4;
			inputcontainer.margin_end = 4;
			inputcontainer.margin_bottom = 4;

// some elements can't edit inputs here
			if (headings[hidx].elements[e].type != "paragraph" && headings[hidx].elements[e].type != "table") {
				print("add input overrides here\n");
			}
			inpcsp = new Gtk.CssProvider();
			inpcss = ".xx { background: #ffDD8820; box-shadow: 2px 2px 2px #00000066; }";
			inpcsp.load_from_data(inpcss.data);
			this.get_style_context().add_provider(inpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.margin_top = 10;
			this.margin_start = 10;
			this.margin_end = 10;
			this.margin_bottom = 10;
			this.append(inputcontainer);
		}
	}
}

public class ParagraphBox : Gtk.Box {
	private Gtk.Box parabox;
	private Gtk.Entry paraname;
	private Gtk.Label paranamelabel;
	private Gtk.Box parainputbox;
	private Gtk.Box parainputcontrolbox;
	private Gtk.Label parainputlabel;
	private Gtk.ToggleButton parainputfoldbutton;
	private string inpcss;
	private Gtk.CssProvider inpcsp;
	private Gtk.Box paraoutputbox;
	private Gtk.Box paraoutputcontrolbox;
	private Gtk.Label paraoutputlabel;
	private Gtk.ToggleButton paraoutputfoldbutton;
	private string oupcss;
	private Gtk.CssProvider oupcsp;
	private string parcss;
	private Gtk.CssProvider parcsp;
	private Gtk.Box paraminputlistbox;
	private Gtk.Box paramoutputlistbox;
	public ParagraphBox (int idx) {
		print("PARAGRAPHBOX: started (%d)\n",idx);
		if (idx < headings[hidx].elements.length) {
			if (headings[hidx].elements[idx].type != null && headings[hidx].elements[idx].type == "paragraph") {
				print("PARAGRAPHBOX:\tfound a paragraph element: %s\n",headings[hidx].elements[idx].name);
				parabox = new Gtk.Box(VERTICAL,10);
				paranamelabel = new Gtk.Label("Name:");
				paraname = new Gtk.Entry();
				parabox.append(paraname);
				paraname.text = headings[hidx].elements[idx].name;
				if (headings[hidx].elements[idx].inputs.length > 0) {
					parainputbox = new Gtk.Box(VERTICAL,4);
					parainputcontrolbox = new Gtk.Box(HORIZONTAL,10);
					paraminputlistbox = new Gtk.Box(VERTICAL,0);
					parainputlabel = new Gtk.Label("Inputs");
					parainputlabel.margin_start = 10;
					parainputlabel.hexpand = true;
					parainputfoldbutton = new Gtk.ToggleButton();
					parainputfoldbutton.icon_name = "go-up";
					parainputfoldbutton.toggled.connect(() => {
						if (parainputfoldbutton.active) {
							parainputfoldbutton.icon_name = "go-down";
							paraminputlistbox.visible = false;
						} else {
							parainputfoldbutton.icon_name = "go-up";
							paraminputlistbox.visible = true;
						}
					});
					parainputcontrolbox.append(parainputlabel);
					parainputcontrolbox.append(parainputfoldbutton);
					parainputbox.append(parainputcontrolbox);
					parainputbox.append(paraminputlistbox);
					parainputcontrolbox.margin_top = 10;
					parainputcontrolbox.margin_bottom = 10;
					parainputcontrolbox.margin_start = 10;
					parainputcontrolbox.margin_end = 10;
					inpcsp = new Gtk.CssProvider();
					inpcss = ".xx { background: #88DDFF20; box-shadow: 2px 2px 2px #00000066; }";
					inpcsp.load_from_data(inpcss.data);
					parainputbox.get_style_context().add_provider(inpcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
					parainputbox.get_style_context().add_class("xx");
					print("PARAGRAPHBOX:\tfetching %d inputs...\n",headings[hidx].elements[idx].inputs.length);
					for (int i = 0; i < headings[hidx].elements[idx].inputs.length; i++) {
						InputRow parainputrow = new InputRow(idx,i);
						paraminputlistbox.append(parainputrow);
					}
					paraminputlistbox.hexpand = true;
					parainputbox.hexpand = true;
					parabox.append(parainputbox);
				}
				if (headings[hidx].elements[idx].outputs.length > 0) {
					paraoutputbox = new Gtk.Box(VERTICAL,4);
					paraoutputcontrolbox = new Gtk.Box(HORIZONTAL,10);
					paramoutputlistbox = new Gtk.Box(VERTICAL,0);
					paraoutputlabel = new Gtk.Label("Outputs");
					paraoutputlabel.margin_start = 10;
					paraoutputlabel.hexpand = true;
					paraoutputfoldbutton = new Gtk.ToggleButton();
					paraoutputfoldbutton.icon_name = "go-up";
					paraoutputfoldbutton.toggled.connect(() => {
						if (paraoutputfoldbutton.active) {
							paraoutputfoldbutton.icon_name = "go-down";
							paramoutputlistbox.visible = false;
						} else {
							paraoutputfoldbutton.icon_name = "go-up";
							paramoutputlistbox.visible = true;
						}
					});
					paraoutputcontrolbox.append(paraoutputlabel);
					paraoutputcontrolbox.append(paraoutputfoldbutton);
					paraoutputbox.append(paraoutputcontrolbox);
					paraoutputbox.append(paramoutputlistbox);
					paraoutputcontrolbox.margin_top = 10;
					paraoutputcontrolbox.margin_bottom = 10;
					paraoutputcontrolbox.margin_start = 10;
					paraoutputcontrolbox.margin_end = 10;
					oupcsp = new Gtk.CssProvider();
					oupcss = ".xx { background: #88DDFF20; box-shadow: 2px 2px 2px #00000066; }";
					oupcsp.load_from_data(oupcss.data);
					paraoutputbox.get_style_context().add_provider(oupcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
					paraoutputbox.get_style_context().add_class("xx");
					print("PARAGRAPHBOX:\tfetching %d outputs...\n",headings[hidx].elements[idx].outputs.length);
					for (int i = 0; i < headings[hidx].elements[idx].outputs.length; i++) {
						OutputRow paraoutputrow = new OutputRow(idx,i);
						paramoutputlistbox.append(paraoutputrow);
					}
					paramoutputlistbox.hexpand = true;
					paraoutputbox.hexpand = true;
					parabox.append(paraoutputbox);
				}
				parabox.margin_top = 10;
				parabox.margin_bottom = 10;
				parabox.margin_start = 10;
				parabox.margin_end = 10;
				parabox.hexpand = true;
				parcsp = new Gtk.CssProvider();
				parcss = ".xx { background: #88888820; box-shadow: 2px 2px 2px #00000066; }";
				parcsp.load_from_data(parcss.data);
				this.get_style_context().add_provider(parcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
				this.get_style_context().add_class("xx");
				this.margin_top = 10;
				this.margin_start = 10;
				this.margin_end = 10;
				this.margin_bottom = 10;
				this.hexpand = true;
				this.append(parabox);
			}
		}
	}
}
/*
public class SourceBox : Gtk.Box {

}

public class ExampleBox : Gtk.Box {

}

public class NameBox : Gtk.Box {

}

public class PropertyBox : Gtk.Box {

}

public class TableBox : Gtk.Box {

}
*/

public class HeadingBox : Gtk.Box {
	private Gtk.Box hbox;
	private Gtk.Entry hname;
	private string hedcss;
	private Gtk.CssProvider hedcsp;
	public HeadingBox (int idx) {
		print("HEADINGBOX: started...\n");
		if (idx < headings.length - 1) {
			print("HEADINGBOX:\tmaking heading for: %s\n",headings[idx].name);
			hbox = new Gtk.Box(HORIZONTAL,10);
			hname = new Gtk.Entry();
			hbox.append(hname);
			hname.text = headings[idx].name;
			this.margin_top = 10;
			this.margin_start = 10;
			this.margin_end = 10;
			this.margin_bottom = 10;
			hedcsp = new Gtk.CssProvider();
			hedcss = ".xx { background: #44444420; box-shadow: 2px 2px 2px #00000066; }";
			hedcsp.load_from_data(hedcss.data);
			this.get_style_context().add_provider(hedcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);
			this.get_style_context().add_class("xx");
			this.append(hbox);
		}
		print("HEADINGBOX: ended.\n");
	}
}

public class ParamBox : Gtk.Box {
	private HeadingBox heb;
	public uint owner;
	private ParagraphBox ebpara;
	public void updateme (uint h){
		print("PARAMBOX.UPDATEME: started...\n");
		print("PARAMBOX.UPDATEME: looking for header: %u\n",h);
		int myh = -1;
		for (int i = 0; i < headings.length; i++) {
			print("PARAMBOX.UPDATEME:\tchecking header id %u\n",headings[i].id);
			if (headings[i].id == h) { myh = i; hidx = i; break; } 
		}
		if (myh != -1) {
			print("PARAMBOX: heading index = %d, owner = %u, heading name = %s\n",myh,owner,headings[myh].name);
			heb = new HeadingBox(myh);
			print("PARAMBOX: hosing myself...\n");
			while (this.get_first_child() != null) { this.get_first_child().destroy(); }
			print("PARAMBOX: i am hosed.\n");
			this.append(heb);
			print("PARAMBOX: header added.\n");
			for (int e = 0; e < headings[myh].elements.length; e++) {
				print("PARAMBOX: checking element %s for type....\n",headings[myh].elements[e].name);
				if (headings[myh].elements[e].type != null) {
					switch (headings[myh].elements[e].type) {
						case "paragraph" : ebpara = new ParagraphBox(e); this.append(ebpara); break;
						//case "propertydrawer" : ebprop = new PropbinBox(e); this.append(ebprop); break;
						//case "srcblock" : ebsrcb = new SrcblockBox(e); this.append(ebsrcb); break;
						//case "example" : ebxmpb = new ExampleBox(e); this.append(ebxmpb); break;
						//case "table" : ebtblb = new TableBox(e); this.append(ebtblb); break;
						//case "comandtag" : ebcmdt = new CmdtagBox(e); this.append(ebcmdt); break;
						//case "nametag" : ebnomt = new NametagBox(e); this.append(ebnomt); break;
						default : break;
					}
				}
			}
		}
	}
	public ParamBox(uint o) {
		print("PARAMBOX: created...\n");
		owner = o;
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.vexpand = false;
		print("PARAMBOX: headings.length = %d, owner = %u, sel = %u\n",headings.length,owner,sel);
		if (headings.length > 0) {
			updateme(o);
		}	
	}
}

public class ModalBox : Gtk.Box {
	private Gtk.Box content;
	private Gtk.Box control;
	private Gtk.Box typelistpopbox;
	private Gtk.Popover typelistpop;
	private Gtk.MenuButton typelistbutton;
	private Gtk.ScrolledWindow typpopscroll;
	private Gtk.GestureClick typelistclick;
	public ModalBox (int typ) {
		print("MODALBOX: created...\n");
// typ 0 = outliner
// typ 1 = parameters
// typ 2 = nodegraph
// typ 3 = processgraph
// typ 4 = timeline
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.vexpand = false;
		content = new Gtk.Box(VERTICAL,0);
		control = new Gtk.Box(HORIZONTAL,0);
		content.vexpand = true;
		control.hexpand = false;
		control.margin_top = 10;
		control.margin_end = 10;
		control.margin_start = 10;
		control.margin_bottom = 10;

		typelistbutton = new Gtk.MenuButton();
		typelistpop = new Gtk.Popover();
		typelistpopbox = new Gtk.Box(VERTICAL,2);
		typpopscroll = new Gtk.ScrolledWindow();

		foreach (string s in paneltypes) {
			Gtk.Button muh = new Gtk.Button.with_label (s);
			typelistpopbox.append(muh);
			muh.clicked.connect ((buh) => {
				if (buh.label == "Parameters") {
					while (content.get_first_child() != null) { content.get_first_child().destroy(); }
					print("MODALBOX: adding parameter pane to content...\n");
					content.append(new ParamBox(sel));
					typelistpop.popdown();
				}
			});
		}
		typelistbutton.icon_name = "document-open-symbolic";
		typelistpopbox.margin_top = 5;
		typelistpopbox.margin_end = 5;
		typelistpopbox.margin_start = 5;
		typelistpopbox.margin_bottom = 5;
		typpopscroll.set_child(typelistpopbox);
		typelistpop.width_request = 300;
		//int wwx, wwy = 0;
		//frownwin.get_default_size(out wwx,out wwy);
		typelistpop.height_request = 200;
		typelistpop.set_child(typpopscroll);
		typelistbutton.popover = typelistpop;
		typelistpop.set_position(TOP);
		typelistclick = new Gtk.GestureClick();
		typelistbutton.add_controller(typelistclick);
		typelistclick.pressed.connect(() => {
			print("typelist selected\n");
		});

		control.append(typelistbutton);

		this.append(content);
		this.append(control);
	}
}


public class frownwin : Gtk.ApplicationWindow {

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

		string sbbackground = "#112633FF";	// sb blue
		string sbselect = "#327299FF";
		string sblines = "#08131AFF";
		string sblight = "#19394DFF";
		string sbshade = "#0C1D26FF";
		string sbentry = "#0E232EFF";

		string out_hi = "#8738A1FF";		// purple
		string out_lo = "#351C3DFF";

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
		
// headerbr buttons

		Gtk.MenuButton savemenu = new Gtk.MenuButton();
		Gtk.MenuButton loadmenu = new Gtk.MenuButton();

		Gtk.GestureClick loadmenuclick = new Gtk.GestureClick();
		loadmenu.add_controller(loadmenuclick);

		savemenu.icon_name = "document-save-symbolic";
		loadmenu.icon_name = "document-open-symbolic";

		Gtk.Button savebutton = new Gtk.Button.with_label("save");
		Gtk.Popover savepop = new Gtk.Popover();
		Gtk.Popover loadpop = new Gtk.Popover();
		Gtk.Box savepopbox = new Gtk.Box(VERTICAL,5);
		Gtk.Box loadpopbox = new Gtk.Box(VERTICAL,5);
		savepopbox.margin_end = 5;
		savepopbox.margin_top = 5;
		savepopbox.margin_start = 5;
		savepopbox.margin_bottom = 5;
		loadpopbox.margin_end = 5;
		loadpopbox.margin_top = 5;
		loadpopbox.margin_start = 5;
		loadpopbox.margin_bottom = 5;
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

// load

		loadmenuclick.pressed.connect(() => {
			if (doup) {
				doup = false;
				while (loadpopbox.get_first_child() != null) {
					//loadpopbox.remove(loadpopbox.get_first_child());
					loadpopbox.get_first_child().destroy();
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
								loadpopbox.append(muh);
								muh.clicked.connect ((buh) => {
									if (buh.label.strip() != "") {
										print("LOAD:\t\tloading %s...\n",buh.label);
										loadmemyorg(buh.label.strip());
										if (headings.length > 0) {
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

		ModalBox panea = new ModalBox(0);
		ModalBox paneb = new ModalBox(1);

// toplevel ui

		vdiv = new Gtk.Paned(VERTICAL);
		vdiv.start_child = panea;
		vdiv.end_child = paneb;
		vdiv.wide_handle = true;
		vdiv.set_shrink_end_child(false);

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
                                                                                           
                                                                                           


// string sbbackground 	= "#112633FF";	// sb blue
// string sbselect 		= "#327299FF";	// bright selection
// string sblines 			= "#08131AFF";	// dark lines
// string sblight 			= "#19394DFF";	// +5 background
// string sbshade 			= "#0C1D26FF";	// -5 background
// string sbentry 			= "#0E232EFF";	// -2 background

// initialize

// events

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