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
string srcblock;
int i;					// carrot. this gets passed around...
element[] elements;
uint qout (string n) {
	for (int i = 0; i < elements.length; i++) {
		for (int q = 0; q < elements[i].outputs.length; q++) {
			if (elements[i].outputs[q].name == n) { return elements[i].outputs[q].id; }
		}
	}
	return -1;
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

bool getorgtext (string[] lines) {
	string txtname = "prose";
	string txt = "";
	for (int c = i; c < lines.length; c++) {
// move the carrot regardless
		i = c;
		string cs = lines[c].strip();
		if (cs.has_prefix("#+") == false) {
			print("[%d]\t plain text: %s\n",i,lines[c]);
			txt = txt.concat(lines[c],"\n");
		} else {
			return false;
		}
	}
	if (txt.length > 0) {
		element ee = element();
		ee.name = txtname;
		ee.id = ee.name.hash();
// minum text size for a [[val:v]] link
		if (txt.length > 9) { 

			if (txt.contains("[[val:")) {
	// ok now for the dumb part:
				string tmptxt = txt;
				string[] l = tmptxt.split("[[val:");
				for (int j = 1; j < l.length; j++) {
					string[] q = l[j].split("]]");
					input qq = input();
					qq.name = q[0];
					qq.id = qq.name.hash();
					qq.org = q[0];
					qq.defaultv = q[0];
					ee.inputs += qq;
					print("[%d](TXT)\tfound var: %s\n",i,q[0]);
				}
			}
		}
		elements += ee;
		print("[%d](TXT)\tsuccessfully captured plain text\n",i);
		return true;
	}
	return false;	
}

bool getorgsrc (string[] lines, bool amnamed) {
// move off the NAME line
	if (amnamed) { i = i + 1; }
	srcblock = "";
	bool amsrc = false;
	for (int c = i; c < lines.length; c++) {
		string cs = lines[c].strip();
		print("[%d] \t\tchecking line : %s\n",c,cs);
		if (cs != "" && amsrc == false) {
			if (cs.has_prefix("#+BEGIN")) {
				print("[%d]\t found src header: %s\n",c,lines[c]);
				srcblock = srcblock.concat(lines[c], "\n");
				amsrc = true; continue;
			} else {
				if (amnamed) { 
// caught something blocking capture of a source block

					print("[%d]\t something blocked capture: %s\n",c,lines[c]);
					i = c;
					return false;
				}
			}
		}
		if (amsrc) {
			if (cs.has_prefix("#+END")) {
				srcblock = srcblock.concat(lines[c]);
				//srcblock._chomp();
				print("[%d]\t\t\t captured source block:\n\t\t\t%s\n",c,srcblock.replace("\n","\n\t\t\t"));
// move to end of src block
				i = c;
				return true;
			}
			srcblock = srcblock.concat(lines[c], "\n");
		}
	}
	srcblock = "";
	return false;
}
bool parseorgsrc (string n, string srcblock) {
	//print("[%d] parseorgsrc (%s, %s)\n", i, n, srcblock);
	element ee = element();
	ee.name = n;
	ee.id = ee.name.hash();
// turn src code into a local param
	string[] h = srcblock.split("\n");
	if (h.length > 1) {
		//print("[%d]\t parsing source code...\n%s\n",i,srcblock);
		print("[%d]\t src block line count is %d\n",i,h.length);
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
	print("[%d]\t looking for elemet type: %s\n",i,hp[0]);
	string[] hpt = hp[0].split(" ");
	if (hpt.length > 1) {
		if (hpt[1] != null) { 
			if (hpt[1] != "") {
				param tt = param();
				tt.name = "type";
				tt.value = hpt[1];
				ee.params += tt;
			}
		}
	}

// get header args
	for (int m = 1; m < hp.length; m++) {
		bool notavar = false;
		print("[%d]\t parsing: %s\n",i,hp[m]);
		if (hp[m].length > 3) {

// turn vars into inputs, sources are checked in a post-process, as the source may not exist yet
			if (hp[m].substring(0,4) == "var ") {
				string[] vp = hp[m].split("=");
				string[] o = {"",""};
				for (int v = 0; v < vp.length; v++) {
					string[] sp = vp[v].strip().split(" ");
					if (sp.length <= 2) {
						if (v == 0) { o[0] = sp[1]; }
						if (v > 0) { 
							if (sp[0] == null || sp[0] == "") { break; }
							o[(o.length - 1)] = sp[0];
							if (sp[1] == null) { break; }
							o += sp[1];
							o += "";
						}
					}
				}
				for (int p = 0; p < o.length; p++) { 
					print("[%d]\t srcblock parameter pair: %s, %s\n", i, o[p], o[(p+1)]);
					input ip = input();
					ip.name = o[p];							// name
					ip.id = ip.name.hash();					// id, probably redundant
					ip.value = o[(p+1)];						// value - volatile
					ip.org = "%s=%s".printf(o[p],o[(p+1)]);	// org syntax
					ip.defaultv = o[(p+1)];					// fallback value if input (override) is connected then disocnnected
					ee.inputs += ip;
					p += 1;
				}
			} else { notavar = true; }
		}

// turn the other args into local params, parser duped for incasement
		if (notavar) {
			if (hp[m].length > 2) {
				string[] rp = hp[i].split("=");
				string[] ro = {"",""};
				for (int v = 0; v < rp.length; v++) {
					string[] rsp = rp[v].strip().split(" ");
					if (rsp.length <= 2) {
						if (v == 0) { ro[0] = rsp[1]; }
						if (v > 0) { 
							if (rsp[0] == null || rsp[0] == "") { break; }
							ro[(ro.length - 1)] = rsp[0];
							if (rsp[1] == null) { break; }
							ro += rsp[1];
							ro += "";
						}
					}
				}
				for (int p = 0; p < ro.length; p++) { 
					print("[%d] srcblock parameter pair: %s, %s\n", i, ro[p], ro[(p+1)]);
					param pp = param();
					pp.name = ro[p];							// name
					pp.value = ro[(p+1)];						// value - volatile
					ee.params += pp;
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
	return true;
}

bool getorgres (string[] lines, element elem, int owner) {
	string resblock = "";
	string resname = elem.name.concat("_result");
	print("[%d](RES)\t result name: %s\n",i,resname);
	bool notnamed = true;
	bool amresult = false;
	for (int b = (i+1); b < lines.length; b++) {
		string bs = lines[b].strip();

// skip newlines
		if (bs != "") {

// look for a name 1st..
			if (bs.has_prefix("#+NAME:")) {
				if (notnamed) { 
					string[] bsp = bs.split(" ");
					if (bsp.length == 2) {
						resname = bsp[1];
						continue;
					} else {

// hit a non-capturing name that blocks result, set line position and abort...
						i = b;
						print("[%d](RES)\t hit a non-capturing NAME: %s\n",i,bs);
						return false;
					}
					notnamed = false;
				} else {

// 2nd name blocks result, set line and abort...
					i = b;
					print("[%d](RES)\t hit a second name block: %s\n",i,bs);
					return false;
				}
			}		

// if capturing result...
			if (amresult) {

// only recognizes : output for now
				if (bs.has_prefix(": ")) { 
					resblock = resblock.concat(lines[b],"\n");
				} else { 

// done capturing result, set element output value, exit
					amresult = false;
					if (resblock.strip() != "") { 
						resblock = resblock.slice(2,(resblock.length - 1));
						elem.outputs[owner].value = resblock._chomp();
					}

// set output name regardless of value
					elem.outputs[owner].name = resname;
					i = b;
					print("[%d](RES)\t captured result: %s\n",i,resname);
					return true;
				}
			} else { 

// ignore results: name, its volatile
				if (bs.has_prefix("#+RESULTS:")) {

// found a result, set to capture mode...
					amresult = true; continue;
				} else {

// something blocks result, set line and abort...
					i = b;
					print("[%d](RES)\t something blocked the result: %s\n",i,bs);
					return false;
				}
			}
		}
	}
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
	string ff = Path.build_filename ("./", "testme.org");
	File og = File.new_for_path(ff);
	string sorg = "";
	try {
		uint8[] c; string e;
		og.load_contents (null, out c, out e);
		sorg = (string) c;
	} catch (Error e) {
		print ("failed to read %s: %s\n", og.get_path(), e.message);
	}
	if (sorg.strip() != "") {
		string propbin = "";
		srcblock = "";
		string results = "";
		string resblock = "";
		i = 0;
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
						print("[%d] found a propbin:\n\t%s\n",i,propbin.replace("\n","\n\t"));
					}
					propbin = ""; allgood = false;
				}
				if (ls.has_prefix("#+NAME:")) {
					string[] lsp = ls.split(" ");
					if (lsp.length == 3) {
						print("[%d] found a #+NAME one-liner: var=%s, val=%s\n\n",i,lsp[1],lsp[2]);
						makememynamevar(lsp[1],lsp[2]);
					}
					if (lsp.length == 2) { 
						srcname = lsp[1]; 
						print("[%d] found a #+NAME capture: %s\n",i,srcname);
						if (getorgsrc(lines,true)) {
							if (parseorgsrc(srcname,srcblock)) {
								print("[%d]\t parsed and captured src block\n",i);
								if (getorgres(lines,elements[(elements.length - 1)],0)) {
									print("[%d]\t\t captured src block result\n",i);
								}
							}
						}
					}
				}
		// capture plain text
				if (ls.has_prefix("#+") == false && ls.has_prefix(":") == false && ls.has_prefix("*") == false) {
					getorgtext(lines);
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