using GLib;

struct output {
	uint id;
	string name;
	string value;
}
struct input {
	uint id;
	string name;
	uint source;
	string value;
	string defaultv;
	string org;
}
struct param {
	string name;
	string value;
}
struct element {
	string name;
	uint id;
	input[] inputs;	// can take input wires
	output[] outputs;	// can be wired out
	param[] params;	// local params; no wiring
}

// globals
// avoid dicking-around with refs, owned, unowned and other vala limitations

string srcblock;
int i;					// carrot. this gets passed around...
string[] hvars;		// header vars
element[] elements;

uint qout (string n) {
	for (int i = 0; i < elements.length; i++) {
		for (int q = 0; q < elements[i].outputs.length; q++) {
			if (elements[i].outputs[q].name == n) { return elements[i].outputs[q].id; }
		}
	}
	return -1;
}

// modulo from 'cdeerinck'
// https://stackoverflow.com/questions/41180292/negative-number-modulo-in-swift#41180619

int imod (int l, int r) {
	if (l >= 0) { return (l % r); }
	if (l >= -r) { return (l + r); }
	return ((l % r) + r) % r;
}

// capture src block header vars

void capcap (string s) {
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
			string vr = s.substring(lidx).strip();
			lidx = vr.index_of(" ") + 1;
			if (lidx > 0 && lidx <= s.length) {
				vr = vr.substring(lidx).strip();
			}
			hvars += vl;
			hvars += vr;
		}
	} else {
		int lidx = s.index_of(" ") + 1;
		if (lidx > 0 && lidx <= s.length) {
			string vl = s.substring(0,lidx);
			string vr = s.substring(lidx).strip();
			hvars += vl;
			hvars += vr;
		}
	}
}

void makememyprops (string b) {
	string[] lines = b.split("\n");
	for (int i = 0; i < lines.length; i++) {
		string lsp = lines[i].strip();
		if (lsp != ":PROPERTIES:" && lsp != ":END:") {
			string[] propparts = lsp.split(":");
			if (propparts.length > 2 && propparts[0].strip() == "") {
				element pb = element();
				pb.name = "property_%s".printf(propparts[1].strip());
				pb.id = pb.name.hash();
				output o = output();
				o.name = propparts[1].strip();
				o.value = propparts[2].strip();
				o.id = o.name.hash();
				//o.owner = pb.id;
				pb.outputs += o;
				elements += pb;
			}
		}	
	}
}
void makememynamevar (string n, string v) {
	element pb = element();
	pb.name = "name_%s".printf(n);
	pb.id = pb.name.hash();
	output o = output();
	o.name = n;
	o.value = v;
	o.id = o.name.hash();
	//o.owner = pb.id;
	pb.outputs += o;
	elements += pb;
}
void makememysrcblock(string n, string c, string r, string v) {
	string[] lines = c.split("\n");
	string[] h = lines[0].split(":");
	if (h.length > 2) {
		foreach (string a in h) { 
			continue;
			string[] ap = a.split(" ");
			if ( ap[0] == "var" ) {
				print("found vars in header: %s\n",a);
			}
		}
	}
}

bool getorgtext (int ind, string[] lines) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	print("[%d]%sgetorgtext started...\n",i,tabs);
	string txtname = "prose";
	string[] txt = {};
	for (int c = i; c < lines.length; c++) {
// move the carrot regardless
		i = c;
		string cs = lines[c].strip();
		if (cs.has_prefix("#+") == false && cs.has_prefix("|") == false && cs.has_prefix("*") == false) {
			print("[%d]%s\tplain text: %s\n",c,tabs,lines[c]);
			txt += lines[c];
		} else {
			break;
		}
	}
	if (txt.length > 0) {
		print("[%d]%s\tsome text was collected, checking it...\n",i,tabs);
		element ee = element();
		ee.name = txtname;
		ee.id = ee.name.hash();
// minum text size for a [[val:v]] link
		for (int d = 0; d < txt.length; d++) {
			if (txt[d].length > 9) { 
				print("[%d]%s\t\tlooking for val:var links in text...\n",i,tabs);
				if (txt[d].contains("[[val:") && txt[d].contains("]]")) {
// ok now for the dumb part:
					int iidx = txt[d].index_of("[[val:");
					int oidx = txt[d].index_of("]]") + 2;
					string chmp = txt[d].substring(iidx,oidx);
					//chmp = chmp.substring(vidx);
					if (chmp != null && chmp != "") {
						print("[%d]%s\t\t\textracted link: %s\n",i,tabs,chmp);
						input qq = input();
						qq.org = chmp;
						qq.defaultv = chmp;
						chmp = chmp.replace("]]","");
						qq.name = chmp.split(":")[1];
						qq.id = qq.name.hash();
						ee.inputs += qq;
						print("[%d]%s\t\t\tstored link ref: %s\n",i,tabs,qq.name);
					}
				}
			}
		}
		elements += ee;
		print("[%d]%s\tsuccessfully captured plain text\n",i,tabs);
		print("[%d]%sgetorgtext ended.\n\n",i,tabs);
		return true;
	}
	print("[%d]%sgetorgtext ended.\n\n",i,tabs);
	return false;	
}

bool getorgsrc (int ind, string[] lines, bool amnamed) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	print("[%d]%sgetorgsrc started...\n",i,tabs);
// move off the NAME line
	if (amnamed) { i = i + 1; }
	srcblock = "";
	bool amsrc = false;
	for (int c = i; c < lines.length; c++) {
		string cs = lines[c].strip();
		print("[%d]%s\tchecking line : %s\n",c,tabs,cs);
		if (cs != "" && amsrc == false) {
			if (cs.has_prefix("#+BEGIN")) {
				print("[%d]%s\t\tfound src header: %s\n",c,tabs,lines[c]);
				srcblock = srcblock.concat(lines[c], "\n");
				amsrc = true; continue;
			} else {
				if (amnamed) { 
// caught something blocking capture of a source block

					print("[%d]%s\tsomething blocked capture: %s\n",c,tabs,lines[c]);
					i = c;	
					print("[%d]%sgetorgsrc ended.\n\n",i,tabs);
					return false;
				}
			}
		}
		if (amsrc) {
			if (cs.has_prefix("#+END")) {
				srcblock = srcblock.concat(lines[c]);
				//srcblock._chomp();
				print("[%d]%s\tcaptured source block:\n\t\t\t%s\n",c,tabs,srcblock.replace("\n","\n\t\t\t"));
// move to end of src block
				i = c;
				print("[%d]%sgetorgsrc ended.\n\n",i,tabs);
				return true;
			}
			srcblock = srcblock.concat(lines[c], "\n");
		}
	}
	srcblock = "";
	print("[%d]%sgetorgsrc ended.\n\n",i,tabs);
	return false;
}
bool parseorgsrc (int ind, string n, string srcblock) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	print("[%d]%sparseorgsrc started...\n",i,tabs);
	//print("[%d] parseorgsrc (%s, %s)\n", i, n, srcblock);
	element ee = element();
	ee.name = n;
	ee.id = ee.name.hash();
// turn src code into a local param
	string[] h = srcblock.split("\n");
	if (h.length > 1) {
		//print("[%d]\t parsing source code...\n%s\n",i,srcblock);
		print("[%d]%s\tsrc block line count is %d\n",i,tabs,h.length);
		string src = "";
		for (int k = 1; k < (h.length); k++) {
			src = src.concat(h[k],"\n");
		}
		src._chomp();
		param cc = param();
		cc.name = n.concat("_code");
		cc.value = src;
		ee.params += cc;
	}

// turn src type into local parameter
	string[] hp = h[0].split(":");
	print("[%d]%s\tlooking for elemet type: %s\n",i,tabs,hp[0]);
	string[] hpt = hp[0].split(" ");
	if (hpt.length > 1) {
		if (hpt[1] != null) { 
			if (hpt[1] != "") {
				param tt = param();
				tt.name = "type";
				tt.value = hpt[1];
				ee.params += tt;
				print("[%d]%s\t\tcaptured type parameter: %s\n",i,tabs,hpt[1]);
			}
		}
	}

// get header args
	for (int m = 1; m < hp.length; m++) {
		bool notavar = false;
		print("[%d]%s\tparsing header arg: %s\n",i,tabs,hp[m]);
		if (hp[m].length > 3) {

// turn vars into inputs, sources are checked in a post-process, as the source may not exist yet
			if (hp[m].has_prefix("var ")) {
				string[] v = hp[m].split("=");
				v[0] = v[0].replace("var ","").strip();
				hvars = {v[0]};
				for (int s = 0; s < v.length; s++) {
					string st = v[s].strip();
					if (st != "") { capcap(st); }
				}
				if ((hvars.length & 1) != 0) {
					hvars[(hvars.length - 1)] = null;
				}
				//foreach (string j in hvars) { if (j != null) { print("\"%s\"\n",j); } }
				for (int p = 0; p < hvars.length; p++) {
					if (hvars[p] != null) {
						print("[%d]%s\t\tvar pair: %s, %s\n", i, tabs, hvars[p], hvars[(p+1)]);
						input ip = input();
						ip.name = hvars[p];								// name
						ip.id = ip.name.hash();							// id, probably redundant
						ip.value = hvars[(p+1)];							// value - volatile
						ip.org = "%s=%s".printf(hvars[p],hvars[(p+1)]);	// org syntax
						ip.defaultv = hvars[(p+1)];						// fallback value if input (override) is connected then disocnnected
						ee.inputs += ip;
					} else { break; }
					p += 1;
				}
			} else { notavar = true; }
		}
		print("[%d]%s\tdone checking header vars...\n",i,tabs);

// turn the other args into local params, check for enclosures
		if (notavar && hp[m] != null) {
			print("[%d]%s\tchecking header params...\n",i,tabs);
			if (hp[m].length > 2) {
				string[] v = hp[m].split(" ");
				string[] o = {};
				for (int g = 0; g < v.length; g++) {
					if (v[g] != null && v[g] != "") {
						string s = v[g].strip();
						print("[%d]%s\t\tchecking param part for enclosures: %s\n",i,tabs,s);
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
								print("[%d]%s\t\t\tenclosures found, capturing: %s\n",i,tabs,vl);
								o += vl;
							}
						} else {
							print("[%d]%s\t\t\tno enclosures found\n",i,tabs);
							o += s;
						}
					}
				}
				//foreach (string j in o) { if (j != null) { print("\"%s\"\n",j); } }
				for (int p = 0; p < o.length; p++) {
					if (o[p] != null) {
						print("[%d]%s\t\tparam name val pair: %s, %s\n", i, tabs, o[p], o[(p+1)]);
						param pp = param();
						pp.name = o[p];								// name
						pp.value = o[(p+1)];							// value - volatile
						ee.params += pp;
					} else { break; }
					p += 1;
				}
			}
		}
	}
// make placeholder output
	output rr = output();
	rr.name = n.concat("_result");
	rr.id = "%s".concat(rr.name).hash();
	ee.outputs += rr;
	elements += ee;
	print("[%d]%sparseorgsrc ended.\n\n",i,tabs);
	return true;
}

bool getorgres (int ind, string[] lines, element elem, int owner) {
	string tabs = ("%-" + ind.to_string() + "s").printf("\t");
	print("[%d]%sgetorgres started...\n",i,tabs);
	string resblock = "";
	string resname = elem.name.concat("_result");
	print("[%d]%s\tresult name: %s\n",i,tabs,resname);
	bool notnamed = true;
	bool amresult = false;
	for (int b = (i+1); b < lines.length; b++) {
		string bs = lines[b].strip();
		print("[%d]%s\tchecking line: %s\n",b,tabs,lines[b]);

// skip newlines
		if (bs != "") {

// look for a name 1st..
			if (bs.has_prefix("#+NAME:")) {
				if (notnamed) { 
					string[] bsp = bs.split(" ");
					if (bsp.length == 2) {
						resname = bsp[1];
						print("[%d]%s\t\tfound a capturing NAME, using it to name result: %s\n",b,tabs,bs);
						continue;
					} else {

// hit a non-capturing name that blocks result, set line position and abort...
						i = b;
						print("[%d]%s\t\thit a non-capturing NAME: %s\n",b,tabs,bs);
						print("[%d]%sgetorgres ended.\n\n",b,tabs);
						return false;
					}
					notnamed = false;
				} else {

// 2nd name blocks result, set line and abort...
					i = b;
					print("[%d]%s\thit a second name block: %s\n",i,tabs,bs);
					print("[%d]%sgetorgres ended.\n\n",i,tabs);
					return false;
				}
			}		

// if capturing result...
			if (amresult) {

// only recognizes : output for now
				if (bs.has_prefix(": ")) { 
					resblock = resblock.concat(lines[b],"\n");
				} else { 
					i = b;
					print("[%d]%s\t\treached end of results...\n",i,tabs);

// done capturing result, set element output value
					amresult = false;
					if (resblock.strip() != "") { 
						print("[%d]%s\t\t\tstoring results...\n",i,tabs);
						resblock = resblock.slice(2,(resblock.length - 1));
						elem.outputs[owner].value = resblock._chomp();
					}

// set output name regardless of value, then bail
					elem.outputs[owner].name = resname;
					print("[%d]%s\t\tcaptured result as: %s\n",i,tabs,resname);
					print("[%d]%sgetorgres ended.\n\n",i,tabs);
					return true;
				}
			} else { 

// ignore results: name, its volatile
				if (bs.has_prefix("#+RESULTS:")) {
					print("[%d]%s\t\tfound start of results block: %s\n",b,tabs,bs);

// found a result, set to capture mode...
					amresult = true; continue;
				} else {

// something blocks result, set line and abort...
					i = b;
					print("[%d]%s\tsomething blocked the result: %s\n",i,tabs,bs);
					print("[%d]%sgetorgres ended.\n\n",i,tabs);
					return false;
				}
			}
		}
	}
	print("[%d]%sgetorgres ended.\n\n",i,tabs);
	return false;
}
void crosscheck () {
	if (elements.length > 0) {
		foreach (unowned element? e in elements) {
			//print("[E]%s\n",e.name);
			if (e.inputs.length > 0) {
				foreach (unowned input? u in e.inputs) {
					//print("[I]\t%s\n",u.name);
					foreach (unowned element? ee in elements) {
						//print("[E]\t\t%s\n",ee.name);
						if (ee.outputs.length > 0) {
							foreach (unowned output? o in ee.outputs) {
								//print("[O]\t\t\t%s\n",o.name);
								if (o.name == u.name) {
									u.source = o.id;
									//print("[R]\t\t\t\tLINKED %u to %u\n",o.id,u.source);
									u.value = o.value;
									//print("[R]\t\t\t\tVALUE: %s\n",u.value);
								}
							}
						}
					}
				}
			}
		}
	}
}

void main (string[] args) {
// load test file
	print("loading testme.org...\n");
	string ff = Path.build_filename ("./", "testme.org");
	File og = File.new_for_path(ff);
	string sorg = "";
	try {
		uint8[] c; string e;
		og.load_contents (null, out c, out e);
		sorg = (string) c;
		print("\ttestme.org loaded.\n");
	} catch (Error e) {
		print ("\tfailed to read %s: %s\n", og.get_path(), e.message);
	}
	if (sorg.strip() != "") {
		string propbin = "";
		srcblock = "";
		string results = "";
		string resblock = "";
		i = 0;
		print("\nreading lines...\n");
		string[] lines = sorg.split("\n");
		for (i = 0; i < lines.length; i++) {
			string srcname = "";
			string ls = lines[i].strip();
			if (ls.length > 0) {
				//print("checking line: %s\n",lines[i]);
				bool allgood = false;
				if (ls == ":PROPERTIES:") {
		// search for end of property bin
		// TODO: add line limit
					for (int b = i; b < lines.length; b++) {
						propbin = propbin.concat(lines[b],"\n");
						if (lines[b].strip() == ":END:") {
							allgood = true; break;
						}
					}
					if (allgood) {
						makememyprops(propbin);
						print("[%d]\tfound a propbin:\n\t%s\n",i,propbin.replace("\n","\n\t"));
					}
					propbin = ""; allgood = false;
				}
				if (ls.has_prefix("#+NAME:")) {
					string[] lsp = ls.split(" ");
					if (lsp.length == 3) {
						print("[%d]\tfound a #+NAME one-liner: var=%s, val=%s\n\n",i,lsp[1],lsp[2]);
						makememynamevar(lsp[1],lsp[2]);
					}
					if (lsp.length == 2) { 
						srcname = lsp[1]; 
						print("[%d]\t\tfound a #+NAME capture: %s\n",i,srcname);
						if (getorgsrc(3,lines,true)) {
							if (parseorgsrc(4,srcname,srcblock)) {
								print("[%d]\t\t\t\tparsed and captured src block\n",i);
								if (getorgres(5,lines,elements[(elements.length - 1)],0)) {
									print("[%d]\t\t\t\t\tcaptured src block result\n",i);
								}
							}
						}
					}
				}
				if (ls.has_prefix("#+BEGIN_SRC")) {
					srcname = ""; srcblock = "";
					if (getorgsrc(2, lines,false)) { 
						if (parseorgsrc(3,srcname,srcblock)) {
							print("[%d]\t\t\tparsed and captured src block\n",i);
							if (getorgres(4,lines,elements[(elements.length - 1)],0)) {
								print("[%d]\t\t\t\tcaptured src block result\n",i);
							}
						}
					}
				}
		// capture plain text
				if (ls.has_prefix("#+") == false && ls.has_prefix(":") == false && ls.has_prefix("*") == false) {
					getorgtext(4,lines);
				}
			}
		}
		crosscheck();
		foreach (element e in elements) {
			print("element: %s\n",e.name);
			foreach (output o in e.outputs) {
				print("\toutput %s: %s\n",o.name,o.value);
			}
			foreach (input u in e.inputs) {
				print("\tinput: | %s | %u | %s |\n",u.name,u.source,u.value);
			}
			foreach (param p in e.params) {
				print("\tparam %s: %s\n",p.name,p.value);
			}
		}
	}
}