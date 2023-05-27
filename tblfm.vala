// parse and run org tblfm expressions
// by c.p.brown, 2023
//
// todo next: hook up addsubtract, clean up dolisp

string[,] orgtodat (string org) {
	string[,] dat = {{""}};
	string[] rr = org.split("\n");
	if (rr[0].has_prefix("|")) {
		int ii = rr[0].index_of("|");
		int oo = rr[0].last_index_of("|");
		int rol = rr[0].length;
		string headrow = rr[0];
		if(oo > (ii + 1)) { headrow = rr[0].substring((ii+1),(oo - (ii + 1))); }
		string[] hh = headrow.split("|");
		string[] headers = {};
		for (int h = 0; h < hh.length; h++) {
			if(hh[h].strip() != "") { headers += hh[h].strip(); }
		}
		int num_rows = 0;
		int num_columns = headers.length;
		for (int r = 0; r < rr.length; r++) {
			if (rr[r] != null && rr[r].strip() != "" && rr[r].has_prefix("|") == true) {
				num_rows += 1;
			}
		}
		dat = new string[num_rows,num_columns];
		int tr = 0;
		for (int r = 0; r < rr.length; r++) {
			if (rr[r] != null && rr[r].strip() != "" && rr[r].has_prefix("|") == true) {
				ii = rr[r].index_of("|");
				oo = rr[r].last_index_of("|");
				if (oo > (ii + 1)) { rr[r] = rr[r].substring((ii+1),(oo - (ii + 1))); }
				string[] cc = rr[r].split("|");
				if (cc.length == 1 && cc[0].contains("-+-")) {
					cc = rr[r].split("+");
				}
				for (int c = 0; c < num_columns; c++) {
					dat[tr,c] = cc[c].strip();
				}
				tr += 1;
			}
		}
	}
	return dat;
}
string reorgtable (string[,] dat) {
	int[] maxlen = new int[dat.length[1]];
	string o = "";
	string hln = "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------";
	for (int m = 0; m < maxlen.length; m++) { maxlen[m] = 0; }
	for (int r = 0; r < dat.length[0]; r++) {
		for (int c = 0; c < dat.length[1]; c++) {
			string lc = dat[r,c].replace("-","");
			if (lc.strip().length == 0) { continue; }
			maxlen[c] = int.max(maxlen[c],dat[r,c].length);
		}
	}
	for (int r = 0; r < dat.length[0]; r++) {
		bool ishline = false;
		string hc = dat[r,0].replace("-","").strip();
		if (hc.length == 0) {
			for (int c = 1; c < dat.length[1]; c++) {
				hc = hc.concat(dat[r,c]);
			}
			hc = hc.replace("-","").strip();
			if (hc.length == 0) { ishline = true; }
		}
		if (ishline) {
			o = o.concat("|");
			for (int c = 0; c < (dat.length[1] - 1); c++) {
				//print("%.*s%s\n",5,s,"heading");
				o = "%s-%.*s%s+".printf(o,maxlen[c],hln,"-");
			}
			o = "%s-%.*s%s|\n".printf(o,maxlen[(dat.length[1] - 1)],hln,"-");
		} else {
			o = o.concat("| ");
			for (int c = 0; c < dat.length[1]; c++) {
				o = "%s%-*s | ".printf(o,maxlen[c],dat[r,c]);
			}
			o._chomp();
			o = o.concat("\n");
		}
	}
	return o;
}
// TODO: handle pre-trimmed input...
int getrefindex (string r, string[,] dat) {
	int o = 0;
	if (r != null && r.strip() != "") {
		string s = r;
		s.canon("1234567890<>I",'.');
		//print("getrefindex: canonized string: %s\n",s);
		int oo = s.index_of(".");
		if (oo > 0) {
			s = s.substring(0,oo);
			//print("getrefindex: sub string: %s\n",s);
			switch (s.get_char(0)) {
				case '>': o = (dat.length[0] - (s.split(">").length - 1)); break;
				case '<': o = s.split("<").length; break;
				case 'I': 
					int qq = 0; 
					int x = s.split("I").length - 1;
					for (int i = 0; i < dat.length[0]; i++) { 
						if (dat[i,0].has_prefix("--")) { 
							qq += 1; 
							if (qq == x) { o = i + 1; break; }
						}
					} break;
				default: o = int.parse(s) - 1; break;
			}
		} else {
			int t = 0;
			if (int.try_parse(s,out t)) { o = t - 1; }
		}
	}
	return o;
}
double doplusminus (string inner) {
	double sm = 0.0;
	if (inner != null && inner.strip() != "") {
		string s = inner;
		if (s.contains("+")) {
			string[] sp = s.split("+");
			if (sp.length == 2) {
				double aa = double.parse(sp[0].strip());
				double bb = double.parse(sp[1].strip());
				sm = aa + bb;
			}
		} else {
			string[] sp = s.split("-");
			if (sp.length == 2) {
				double aa = double.parse(sp[0].strip());
				double bb = double.parse(sp[1].strip());
				sm = aa - bb;
			}
		}
	}
	return sm;
}
double domultdiv (string inner) {
	double sm = 0.0;
	if (inner != null && inner.strip() != "") {
		string s = inner;
		if (s.contains("*")) {
			string[] sp = s.split("*");
			if (sp.length == 2) {
				double aa = double.parse(sp[0].strip());
				double bb = double.parse(sp[1].strip());
				sm = aa * bb;
			}
		} else {
			string[] sp = s.split("/");
			if (sp.length == 2) {
				double aa = double.parse(sp[0].strip());
				double bb = double.parse(sp[1].strip());
				sm = aa / bb;
			}
		}
	}
	return sm;
}
double doformat (string n) {
	if (n != null && n != "") {
		string[] np = n.split(";");
		if (np.length == 2) {
			if (np[0] != "" && np[1] != "") {
				//print("np[0] = %s\n",np[0]);
				//print("np[1] = %s\n",np[1]);
				string h = np[1].printf(double.parse(np[0]));
				//print("h = %s\n",h);
				return double.parse(h);
			}
		}
	}
	return 0.0;
}
string evallisp (int myr, int myc, string instr, string[,] tbldat) {
	string inner = instr;
	double lm = 0.0;
	if (inner != null && inner.strip() != "") {
		print("evallisp: inner = %s\n",inner);
		int ii = 0;
		int ic =  1;
		int aii = 0;
		int oo = 0;
		int r = -1;
		int c = -1;
// replace cell refs with data
		string s = inner;
		if (inner.contains("@") || inner.contains("$")) {
			print("evallisp: getting row & col data...\n");
			int y = 0;
			while (s.contains("@") ||  s.contains("$")) {
				oo = -1;
				if (y > 5) { break; }
				aii = s.index_of("@");
				if (ii < 0) { r = myr; } else {
					string rs = s.substring((aii+1));
					//print("evallisp: rs: %s\n",rs);
					r = getrefindex(rs, tbldat);
					rs.canon("1234567890<>I",'.');
					//print("evallisp: canonized string: %s\n",rs);
					oo = rs.index_of(".");
					if (oo > 0) { oo = oo + ii + 1; }
				}
				print("evallisp: row = %d\n",r);
				ii = s.index_of("$");
				if (ii < 0) { c = myc; } else {
					string cs = s.substring((ii+1));
					//print("evallisp: cs: %s\n",cs);
					c = getrefindex(cs, tbldat);
					cs.canon("1234567890<>I",'.');
					//print("evallisp: canonized string: %s\n",cs);
					oo = cs.index_of(".");
					if (oo > 0) { oo = oo + ii + 1; }
				}
				print("evallisp: column = %d\n",c);
				if (r < tbldat.length[0] && c < tbldat.length[1]) {
					if (oo > ii) {
						inner = inner.splice(aii,oo,tbldat[r,c]);
						s = s.splice(aii,oo,tbldat[r,c]);
					}
				}
				y += 1;
			}
			print("evallisp: spliced string: %s\n",inner);
		}
		
		if (inner.contains("format")) { 
			print("evallisp: parsing format...\n");
			inner = inner.replace("format","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			int ptl = 0;
			string[] k = {};
			foreach (string g in pts) { if (g.strip() != "") { ptl += 1; k += g.strip(); } }
			if (k.length > 1 && k[0].contains("%")) {
				print("evallisp: getting tokens in %s\n",k[0]);
				int n = 1;
				int ival = 0;
				double dval = 0.0;
				string sval = "";
				k[0] = k[0].replace("%","%%");
				int y = 0;
				while (k[0].contains("%")) {
					print("n = %d, k.length = %d\n",n,k.length);
					if (y > 10) { break; }
					ii = k[0].index_of("%");
					//print("ii = %d, k[0].length = %d\n",ii,k[0].length);
					string tk = k[0].substring(ii,3);
					//if (tk == "%d") {
					if (strcmp(tk,"%%d") == 0) {
						if (int.try_parse(k[n],out ival)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							print("spliced format: %s\n",k[0]);
							n += 1;
						} else { return "ERROR: format arg %d not an int".printf(n); }
					}
					if (strcmp(tk,"%%f") == 0) {
						print("splicing k[%d] %s\n",n,k[n]);
						if (double.try_parse(k[n],out dval)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							print("spliced format: %s\n",k[0]);
							n += 1;
						} else { return "ERROR: format arg %d not an int".printf(n); }
					}
					if (strcmp(tk,"%%s") == 0) {
						print("splicing k[%d] %s\n",n,k[n]);
						k[0] = k[0].splice(ii,(ii+3),k[n]);
						print("spliced format: %s\n",k[0]);
						n += 1;
					}
					y += 1;
				}
				return k[0];
			}
		}
		if (inner.contains("make-string")) {
// (make-string 5 ?x)
			inner = inner.replace("make-string","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			if (pts.length > 1 && pts[0] != "") {
				bool docount = false;
				for (int h = 0; h < pts.length; h++) {
					string hh = pts[h].replace("\"","").strip();
					if (pts[h].has_prefix("?") == false) {
						pts[0] = "%.*s".printf(ic,hh);
					}
					ic = 1;
					docount = int.try_parse(hh,out ic);
				}
				return string.joinv(" ",pts);
			}
		}
		if (inner.contains("string")) { }
		if (inner.contains("substring")) { }
		if (inner.contains("concat")) { }
		if (inner.contains("downcase")) { return inner.down(); }
		if (inner.contains("upcase")) { return inner.replace("\"","").up(); }
// number
		if (inner.contains("abs")) { }
		if (inner.contains("mod")) { }
		if (inner.contains("random")) { }
		if (inner.contains("fceiling")) { }
		if (inner.contains("ffloor")) { }
		if (inner.contains("fround")) { }
		if (inner.contains("ftruncate")) { }
		if (inner.contains("min")) { }
		if (inner.contains("max")) { }
		if (inner.contains("exp")) { }
		if (inner.contains("log")) { }
		if (inner.contains("sin")) { }
		if (inner.contains("cos")) { }
		if (inner.contains("tan")) { }
		if (inner.contains("asin")) { }
		if (inner.contains("acos")) { }
		if (inner.contains("atan")) { }
		if (inner.contains("sqrt")) { }
		if (inner.contains("float-pi")) { }
	}
	return "";
}
double dosum (string inner, string[,] dat) {
	double sm = 0.0;
	if (inner != null && inner.strip() != "") {
		int ii = 0;
		int oo = 0;
		int cf = 0;
		int ct = 0;
		int rf = 0;
		int rt = 0;
		string s = inner;
		ii = s.index_of("@");
		oo = s.index_of("$");
		string r = s.substring((ii+1));
		rf = getrefindex(r,dat);
		s = s.splice((ii),(oo),"");

		ii = s.index_of("$");
		oo = s.index_of("..");
		string c = s.substring((ii+1));
		cf = getrefindex(c,dat);
		s = s.splice((ii),(oo),"");

		ii = s.index_of("@");
		oo = s.index_of("$");
		string rr = s.substring((ii+1));
		rt = getrefindex(rr,dat);
		s = s.splice((ii),(oo),"");

		ii = s.index_of("$");
		oo = s.index_of(")");
		string cc = s.substring((ii+1));
		ct = getrefindex(cc,dat);

		if (rf == rt) {
			for (int i = cf; i <= ct; i++) { 
				double dd = double.parse(dat[rf,i]);
				if ( dd > 0.0) { sm += dd; }
			}
			print("\t\thsum = %f\n",sm);
		}
		if (cf == ct) {
			for (int i = rf; i <= rt; i++) { 
				double dd = double.parse(dat[i,cf]);
				if ( dd > 0.0) { sm += dd; }
			}
			print("\t\tvsum = %f\n",sm);
		}
	}
	return sm;
}
string dotblfm (int x, int y, string e, string[,] tbldat) {
	string o = e;
	int z = 0;
	while (o.contains("(")) {
		if (z > 4) { break; }
		int ii = o.last_index_of("(");
		string m = o.substring(ii);
		int oo = m.index_of(")") + 1;
		string inner = o.substring(ii,oo);
		print("inner expression: %s\n",inner);
		if (inner.contains("..")) {
			m = o.substring(0,ii);
			print("before expression : %s\n",m);
			double  sm = dosum(inner,tbldat);
			ii = m.last_index_of("vsum");
			print("sum = %f\n",sm);
			o = o.splice(ii,(oo + ii + 4),"%f".printf(sm));
			print("spliced expression = %s\n",o);
			continue;
		}
		if (inner.contains("/") || inner.contains("*")){
			inner = inner.replace("(",""); inner = inner.replace(")","");
			double sm = domultdiv(inner);
			print("result = %f\n",sm);
			o = o.splice(ii,(oo + ii),"%f".printf(sm));
			print("spliced expression = %s\n",o);
		}
		z += 1;
	}
	return o;
}
string dolisp (int x, int y, string e, string[,] tbldat) {
	print("looking for lisp expression...\n");
	int[] eps = {};
	char q = '\'';
	string o = e;
	for (int c = 0; c < e.length; c++) {
		//print("\tchecking char %c == %c\n",e[c],q);
		if (e[c] == q) {
			//print("\t\tmatch.\n");
			if ((c+1) < e.length) {
				if (e[(c+1)] == '(') {
					//print("\t\tmatch.\n");
					eps += (c + 1);
				}
			}
		}
	}
	if (eps.length > 0) { 
		print("lisp expression starts at %d\n",eps[0]);
		int[] po = {};
		int[] pc = {};
		for (int p = eps.length; p >= 0; p --) {
			for (int c = eps[p]; c < e.length; c++) {
				if (e[c] == '(') { po += c; }
				//print("\tchecking char %c == )\n",e[c]);
				if (e[c] == ')') { 
					print("\tindex of ) %d == e.length %d\n",c,e.length);
					if (c < e.length) { 
						pc += c; 
					} 
				}
			}
		}
		print("sub expression open count is %d, close count is %d\n",po.length,pc.length);
		if ( po.length == pc.length ) {
			int pmax = (po.length - 1);
			for (int p = 0; p < po.length; p++) {
				int t = po[p];
				po[p] = po[pmax - p];
				po[pmax - p] = t;
			}
			for (int p = 0; p < po.length; p++) {
				print("po[%d] = %d\n",p,po[p]);
				print("pc[%d] = %d\n",p,pc[p]);
				int ii = po[p];
				int oo = pc[p];
				if (oo > ii) {
					string inner = e.substring(ii,(oo-(ii - 1)));
					inner = inner.replace("\"","");
					print("inner elisp expression %d is: %s\n",p,inner);
					o = evallisp(x,y,inner,tbldat);
				}
			}
		}
	} else { print("no lisp expression found...\n"); }
	return o;
}

void main() {
	int64 ofmts = GLib.get_real_time();
	string[,] dat;
	string orgtbl = """| AA     | BB    | CC     | DD       |\n
|--------+-------+--------+----------|\n
| 68.0   | 39.47 | 128.15 | 337.59   |\n
| 403.88 | 16.21 | 117.03 | 9.0      |\n
| 5.8    | 14.73 | 58.1   | 107.64   |\n
|--------+-------+--------+----------|\n
|        |       |        |          |""";

	dat = orgtodat(orgtbl);
	string theformula = "@>$4=((vsum(@I$4..@>>>$4) / 1000.0) * 20.0);%.2f\n@>$2='(format \"%s_%f\" @1$2 @>>>$1)";
	//string e = theformula;
	// we need 9.0846 from the above
	string[] xprs = theformula.split("\n");
		int ii = 0;
		int oo = 0;
		int r = 0;
		int c = 0;
		bool islisp = false;
		bool wassum = false;
		bool waslisp = false;
		string fm = "";
	foreach (string e in xprs) {
		print("readig formula : %s\n",e);
		string[] ep = e.split("=");
		ii = 0;
		oo = 0;
		r = 0;
		c = 0;
		islisp = false;
		wassum = false;
		waslisp = false;
		fm = "";
		if (ep.length == 2) {
			ep[0] = ep[0].strip();
			ep[1] = ep[1].strip();
			if (ep[0] != "" && ep[1] != "") {
				ii = ep[0].index_of("@");
				oo = ep[0].index_of("$");
				string rs = ep[0].substring((ii+1));
				r = getrefindex(rs,dat);
				print("target row: %d %s",r,rs);
				string cs = ep[0].substring((oo + 1));
				c = getrefindex(cs,dat);
				print(", target col: %d, %s\n",c,cs);
				int sks = 0;
				ep[1] = dolisp(r,c,ep[1],dat);
				ep[1] = dotblfm(r,c,ep[1],dat);
				print("checking formula val type: %s\n",ep[1]);
				if (ep[1].contains(";")) {
					fm = "%f".printf(doformat(ep[1]));
				} else {
					fm = ep[1];
				}
				print("\nformula changed dat[%d,%d] from \"%s\" to %s\n\n",r,c,dat[r,c],fm);
				dat[r,c] = fm;
				print("%s\n",reorgtable(dat));
				print("\n#+TBLFM: %s\n",theformula);
				int64 ofmte = GLib.get_real_time();
				print("\ntable formula edit took %f microseconds\n\n",((double) (ofmte - ofmts)));
			}
		}
	}
}
