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
	// n name of block
	// c code
	// r result name
	// v result

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

string[] lines;	// generic search
string srcblock;	// captured source block
string propbin;	// captured property bin
string results;	// captures results (redundant)
//
//                                    getsrc
//                                      |
//                  getname          parsesrc
//                     |                |
//                     +.....+------+---+---+-------+
//                     |     |      |       |       |
//                     |     |      |       |     getres
//                     |     |      |       |       |
//                     |     |      |       |    parseres
//                     |     |      |       |       |
// makemeasrcelement( name, type, inp[], params[], oup) 
//
bool getsrc (int i) {
// capture 1st line to extract headers later
	srcblock = "";
	for (int b = i; b < lines.length; b++) {
		string bs = lines[b].strip();
		if (bs == "") { return false; }
		if (bs.length > 6) {
			if (bs.substring(0,7) == "#+BEGIN") {
				print("found a NAMEd src block: %s\n",bs);
				for (int c = b; c < lines.length; c++) {
					string cs = lines[c].strip();
					if (cs.length > 4) {
						if (cs.substring(0,5) == "#+END") {
							//srcblock = srcblock.slice(0,(srcblock.length - 1));
							srcblock._chomp();
							print("\t\tcaptured source block:\n%s\n",srcblock);
							return true;
						}
					}
					srcblock = srcblock.concat(lines[c], "\n");
				}
			}
		}
	}
	srcblock = "";
	return false;
}
bool parsesrc (string n) {
	element ee = element();
	ee.name = n;
	ee.id = ee.name.hash();
// turn src code into a local param
	string[] h = srcblock.split("\n");
	if (h.length > 1) {
		print("parsing source code...\n%s\n",srcblock);
		print("src block line count is %d\n",h.length);
		string src = "";
		for (int i = 1; i < (h.length); i++) {
			src = src.concat(h[i],"\n");
		}
		src._chomp();
		param cc = param();
		cc.name = n.concat("_code");
		cc.value = src;
		ee.params += cc;
	}

// turn src type into local parameter
	string[] hp = h[0].split(":");
	print("looking for elemet type: %s\n",hp[0]);
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
	for (int i = 1; i < hp.length; i++) {
		bool notavar = false;
		print("parsing: %s\n",hp[i]);
		if (hp[i].length > 3) {

// turn vars into inputs, sources are checked in a post-process, as the source may not exist yet
			if (hp[i].substring(0,4) == "var ") {
				string[] vp = hp[i].split("=");
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
					print("srcblock parameter pair: %s, %s\n", o[p], o[(p+1)]);
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
			if (hp[i].length > 2) {
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
					print("srcblock parameter pair: %s, %s\n", ro[p], ro[(p+1)]);
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
bool getres (int i) {
	for (int b = (i + 1); b < lines.length; b++) {
		string bs = lines[b].strip();
		if (bs == "") { return false; }
		if (bs.length > 6) {
			if (bs.substring(0,7) == "#+BEGIN") {
				print("\tfound a NAMEd src block: %s\n",bs);
				print("\t\tcheck b: %d, lines.length: %d\n",b,lines.length);
				for (int c = b; c < lines.length; c++) {
					srcblock = srcblock.concat(lines[c],"\n");
					string cs = lines[c].strip();
					if (cs.length > 4) {
						print("\t\tcheck substring for END...\n");
						if (cs.substring(0,5) == "#+END") {
							srcblock = srcblock.concat(lines[c],"\n");
							print("\t\tcaptured source block\n");
							return true;
						}
					}
				}
			}
		}
	}
	return false;
}
void main (string[] args) {
// dummy data
string sorg = """* an aricle
:PROPERTIES:
:STATE: ACT
:END:

#+NAME: postcode 12345

#+NAME: burb
#+BEGIN_SRC shell :var x="Tuggeranong" y = "Fadden"
echo $x
.
#+END_SRC

#+NAME: burb_result
#+RESULTS:
: Tuggeranong

send it to:
[[val:burb_result]] [[val:STATE]] [[val:postcode]] Australia

""";
propbin = "";
srcblock = "";
results = "";
lines = sorg.split("\n");
for (int i = 0; i < lines.length; i++) {
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
				print("found a propbin:\n%s\n",propbin);
				makememyprops(propbin);
			}
			propbin = ""; allgood = false;
		}
		if (ls.length > 6) {
			if (ls.substring(0,7) == "#+NAME:") {
				string[] lsp = ls.split(" ");
				if (lsp.length == 3) {
					print("\tfound a #+NAME one-liner: var=%s, val=%s\n\n",lsp[1],lsp[2]);
					makememynamevar(lsp[1],lsp[2]);
				}
				if (lsp.length == 2) {
// find something to capture,
					print("\tsearching for something NAMEd...\n");
					if (getsrc(i)) {
						print("\tparsing srouce block: %s...\n",lsp[1]);
						if (parsesrc(lsp[1])) {
							print("parsed src block:\n");
						}
					}
				}
			}
		}
	}
}
foreach (element e in elements) {
	print("element: %s\n",e.name);
	for (int i = 0; i < e.outputs.length; i++) {
		print("\toutput %s: %s\n",e.outputs[i].name,e.outputs[i].value);
	}
	for (int i = 0; i < e.inputs.length; i++) {
		print("\tinput %s: %s\n",e.inputs[i].name,e.inputs[i].value);
	}
	for (int i = 0; i < e.params.length; i++) {
		print("\tparam %s: %s\n",e.params[i].name,e.params[i].value);
	}
}
	// AA links to CC and EE
	// BB links to EE
	// DD links to BB
	// CC links to BB
}