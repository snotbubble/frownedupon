// parse and run org tblfm expressions
// by c.p.brown, 2023
//
// todo next: finish elisp functions

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
// separate subtraction (a - b) from negative (-a)
string subminus (string s) {
	string o = s;
	if (s.contains("-")) {
		char[] nums = {'0','1','2','3','4','5','6','7','8','9'};
		for (int h = 0; h < s.length; h++) {
			if (s[h] == '-') {
				if (h > 0 && h < (s.length - 1)) {
					if (s[(h-1)] in nums && s[(h+1)] in nums) { o = o.splice(h,(h+1),"!"); } else {						// 3-1
						if (s[(h-1)] == ')' && s[(h+1)] in nums) {  o = o.splice(h,(h+1),"!");  } else {					// )-1
							if (s[(h-1)] == ')' && s[(h+1)] == '(') { o = o.splice(h,(h+1),"!"); } else {					// )-(
								if (s[(h-1)] in nums && s[(h+1)] == ' ') { o = o.splice(h,(h+1),"!"); } else {				// 3- 
									if (s[(h-1)] in nums && s[(h+1)] == '(') { o = o.splice(h,(h+1),"!"); } else {			// 3-(
										if (s[(h-1)] == ')' && s[(h+1)] == ' ') { o = o.splice(h,(h+1),"!"); } else {		// )- 
											if (s[(h-1)] == ' ' && s[(h+1)] == ' ') { o = o.splice(h,(h+1),"!"); }			//  - 
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
return o;
}
string replacerefs (int myr, int myc, string inner, string[,] tbldat) {
	if (inner != null && inner.strip() != "") {
		string s = inner;
		if (inner.contains("@") || inner.contains("$")) {
			int[] rc = {-1,-1};
			int y = 0;
			int b = 0;
			int r = myr;
			int c = myc;
			while (s.contains("@") || s.contains("$")) {
				if (y > 100) {break;}
				string t = s; t.canon("$@1234567890<>I",'.');
				//print("\tevallisp: s.canon = %s\n",t);
				for (int h = b; h < t.length; h ++) {
					//print("evallisp: \tchecking char %d %c in block starting at %d\n",h,t[h],b);
					if (t[h] == '.' || (h == t.length - 1)) {
						if ((rc[0] + rc[1]) != -2) {
							//print("evallisp: \t\trc[0] = %d, rc[1] = %d\n",rc[0],rc[1]);
							if (rc[0] == -1) { r = myr; rc[0] = 99999; }
							if (rc[1] == -1) { c = myc; rc[1] = 99999;}
							//print("evallisp: \t\tr = %d, c = %d\n",r,c);
							s = s.splice(int.min(rc[0],rc[1]),h,tbldat[r,c]);
							print("replacerefs: \tspliced expression: %s\n",s);
						}
						rc = {-1,-1};
						b = ((h + 1) - (t.length - s.length));
						r = myr; c = myc;
						break;
					}
					if (t[h] == '$') { 
						string cs = t.substring((h+1));
						//print("\tevallisp: \t\tcs = %s\n",cs);
						rc[1] = h;
						c = getrefindex(cs, tbldat);
						//print("\tevallisp: \t\tc = %d\n",c);
					}
					if (t[h] == '@') {
						string rs = t.substring((h + 1));
						//print("\tevallisp: \t\trs = %s\n",rs);
						rc[0] = h;
						r = getrefindex(rs, tbldat);
						//print("\tevallisp: \t\tr = %d\n",r);
					}
				}
				y += 1;
			}
			return s;
			print("\tevallisp: spliced string: %s\n\n",inner);
		}
	}
	return inner;
}
string domaths (int myr, int myc, string inner, string[,] tbldat) {
	string o = inner;
	string[] ops = {"*", "/", "+", "!"};
	if (inner != null && inner.strip() != "") {
		string s = replacerefs(myr, myc, inner, tbldat);
		s = subminus(s); s = s.replace("-"," -");
		print("domaths: expression: %s\n",s);
		int y = 0;
		foreach (string x in ops) {
			//if (s.contains(x)) {
			while (s.contains(x)) {
				//print("domaths: \texpression contains %s\n",x);
				if (y > 10) { break; }
				double sm = 0.0;
				string t = s; 
				//t = subminus(t);
				switch (x) {
					case "*": t.canon("1234567890.*-",'_'); break;
					case "/": t.canon("1234567890./-",'_'); break;
					case "+": t.canon("1234567890.+-",'_'); break;
					case "!": t.canon("1234567890.!-",'_'); break;
					default:  t.canon("1234567890.",'_'); break;
				}
				print("domaths: \ts.canon: %s\n",t);
				string[] sp = t.split(x);
				if (sp.length > 1) {
					//print("domaths: \tleft = %s, right = %s\n",sp[0],sp[1]);
					int aii = 0;
					int oo = sp[1].length - 1;
					int splen = sp[0].length;
					if (sp[0].length > 0 && sp[0].contains("_")) {
						for ( int h = (sp[0].length - 1); h >= 0; h--) { 
							//print("domaths: \tleft tail search at %d: %c == %c ?\n",h,sp[0][h],'_');
							if (sp[0][h] != '_') { oo = h; break; } 
						}
						for ( int h = oo; h >= 0; h--) { 
							//print("domaths: \tleft head search at %d: %c == %c ?\n",h,sp[0][h],'_');
							if (sp[0][h] == '_') { aii = h + 1; break; } 
						}
						//if (oo > 0 && oo < (sp[0].length - 2)) { oo += 1; }
						//print("domaths: left starts at %d, ends at %d\n",aii,oo);
						if (aii < sp[0].length && aii < oo && oo < sp[0].length) { 
							sp[0] = sp[0].substring(aii,(oo - aii + 1)); 
							//print("domaths: left substring(%d,%d): %s\n",aii,(oo - aii),sp[0]);
						} 
					}
					int ii = 0;
					if (sp[1].length > 0 && sp[1].contains("_")) {
						for ( int h = (sp[1].length - 1); h >= 0; h--) { if (sp[1][h] != '_') { oo = h; break; } }
						for ( int h = oo; h >= 0; h--) { if (sp[1][h] == '_') { ii = h + 1; break; } }
						if (ii < sp[1].length && ii < oo && oo < sp[1].length) { 
							sp[1] = sp[1].substring(ii,(oo - ii + 1)); 
							//print("domaths: right substring(%d,%d): %s\n",ii,(oo - ii + 1),sp[1]);
						}
					}
					//print("domaths: \tleft = %s, right = %s\n",sp[0],sp[1]);
					oo = oo + splen + 2;
					double aa = 0.0;
					double bb = 0.0;
					if (double.try_parse(sp[0].strip(),out aa)) {
						if (double.try_parse(sp[1].strip(),out bb)) {
							switch (x) {
								case "*": sm = aa * bb; break;
								case "/": sm = aa / bb; break;
								case "+": sm = aa + bb; break;
								case "!": sm = aa - bb; break;
								default: sm = 0.0; break;
							}
						} else { print("ERROR: %s or %s are not float",sp[0],sp[1]); break; }
					} else { print("ERROR: %s or %s are not float",sp[0],sp[1]); break; }
					//print("domaths: s.length: %d\n",s.length);
					print("domaths: \tsplicing from %d to %d\n",aii,oo);
					if (aii >= 0 && aii < s.length && aii < oo) {
						if (oo > aii && oo <= s.length) {
							s = s.splice(aii,oo,"%f".printf(sm));
							print("domaths: spliced expression: %s\n",s);
						}
					}
					y += 1;
				} else { break; }
			}
		}

		//}
		o = s;
	}
	return o;
}
string doformat (string n) {
	if (n != null && n != "") {
		string[] np = n.split(";");
		if (np.length == 2) {
			if (np[0] != "" && np[1] != "") {
				//print("np[0] = %s\n",np[0]);
				//print("np[1] = %s\n",np[1]);
				string h = np[1].printf(double.parse(np[0]));
				//print("h = %s\n",h);
				return h;
			}
		}
	}
	return n;
}
string evallisp (int myr, int myc, string instr, string[,] tbldat) {
	string inner = instr;
	double lm = 0.0;
	if (inner != null && inner.strip() != "") {
		print("\n\tevallisp: inner = %s\n",inner);
		int ic = 1;
		int ii = -1;
		int oo = -1;
		int r = myr;
		int c = myc;
		
		if (inner.contains("format")) { 
			print("\tevallisp format %s...\n",inner);
			inner = inner.replace("format","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			int ptl = 0;
			string[] k = {};
			foreach (string g in pts) { if (g.strip() != "") { ptl += 1; k += g.strip(); } }
			if (k.length > 1 && k[0].contains("%")) {
				print("\tevalelisp format: \tgetting tokens in %s\n",k[0]);
				int n = 1;
				int ival = 0;
				double dval = 0.0;
				string sval = "";
				k[0] = k[0].replace("%","%%");
				int y = 0;
				while (k[0].contains("%")) {
					//print("n = %d, k.length = %d\n",n,k.length);
					if (y > 10) { break; }
					ii = k[0].index_of("%");
					//print("ii = %d, k[0].length = %d\n",ii,k[0].length);
					string tk = k[0].substring(ii,3);
					//if (tk == "%d") {
					if (strcmp(tk,"%%d") == 0) {
						if (int.try_parse(k[n],out ival)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							print("\tevalelisp format: \tspliced format: %s\n",k[0]);
							n += 1;
						} else { return "ERROR: format arg %d not an int".printf(n); }
					}
					if (strcmp(tk,"%%f") == 0) {
						//print("\tevalelisp format: \tsplicing k[%d] %s\n",n,k[n]);
						if (double.try_parse(k[n],out dval)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							print("\tevalelisp format: \tspliced format: %s\n",k[0]);
							n += 1;
						} else { return "ERROR: format arg %d not an int".printf(n); }
					}
					if (strcmp(tk,"%%s") == 0) {
						//print("\tevalelisp format: \tsplicing k[%d] %s\n",n,k[n]);
						k[0] = k[0].splice(ii,(ii+3),k[n]);
						print("\tevalelisp format: \tspliced format: %s\n",k[0]);
						n += 1;
					}
					y += 1;
				}
				print("\n");
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
				print("\n");
				return string.joinv(" ",pts);
			}
		}
		if (inner.contains("string")) { }
		if (inner.contains("substring")) { }
		if (inner.contains("concat")) { 
// (concat "s" "s")
			inner = inner.replace("concat","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			if (pts.length > 0 && pts[0] != "") {
				for (int h = 0; h < pts.length; h++) {
					string hh = pts[h].replace("\"","").strip();
					pts[h] = hh;
				}
				print("\n");
				return string.joinv("",pts);
			}
		}
		if (inner.contains("downcase")) { 
			print("\tevallisp downcase %s...\n",inner);
			inner = inner.replace("downcase","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			print("\n");
			return inner.down(); 
		}
		if (inner.contains("upcase")) { 
			print("\tevallisp upcase %s...\n",inner);
			inner = inner.replace("upcase","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			print("\n");
			return inner.up(); 
		}
// number
		if (inner.contains("abs")) { 
			inner = inner.replace("abs","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.strip().split(" ");
			if (pts.length == 1 && pts[0] != "") {
				double v = 0.0;
				if (double.try_parse(pts[0], out v)) {
					v = v.abs();
					return "%f".printf(v);
				}
			}
		}
		if (inner.contains("mod")) { }
		if (inner.contains("random")) { }
		if (inner.contains("fceiling")) { }
		if (inner.contains("ffloor")) { }
		if (inner.contains("fround")) { }
		if (inner.contains("ftruncate")) { }
		if (inner.contains("min")) { 
			inner = inner.replace("min","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.strip().split(" ");
			if (pts.length > 1 && pts[0] != "") {
				double v = 0.0;
				if (double.try_parse(pts[0], out v)) {
					for (int h = 1; h < pts.length; h++) {
						double j = 0.0;
						if (double.try_parse(pts[h],out j)) {
							v = double.min(v,j);
						}
					}
					return "%f".printf(v);
				}
			}
		}
		if (inner.contains("max")) { 
			inner = inner.replace("max","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.strip().split(" ");
			if (pts.length > 1 && pts[0] != "") {
				double v = 0.0;
				if (double.try_parse(pts[0], out v)) {
					for (int h = 1; h < pts.length; h++) {
						double j = 0.0;
						if (double.try_parse(pts[h],out j)) {
							v = double.max(v,j);
						}
					}
					return "%f".printf(v);
				}
			}
		}
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
	return instr;
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
	if (e != null && e.strip() != "") {
		string o = e;
		int z = 0;
		int ii = -1;
		int oo = -1;
		string inner = e;
		while (o.contains("(")) {
			if (z > 50) { break; }
			ii = o.last_index_of("(");
			string m = o.substring(ii);
			oo = m.index_of(")") + 1;
			inner = o.substring(ii,oo);
			print("tblfm: inner expression: %s\n",inner);
			if (inner.contains("..")) {
				m = o.substring(0,ii);
				//print("before expression : %s\n",m);
				double  sm = dosum(inner,tbldat);
				ii = m.last_index_of("vsum");
				print("tblfm: sum = %f\n",sm);
				o = o.splice(ii,(oo + ii + 4),"%f".printf(sm));
				print("tblfm: spliced expression = %s\n",o);
				continue;
			}
			if (inner.contains("/") || inner.contains("*") || inner.contains("+") || inner.contains("-")){
				inner = inner.replace("(",""); inner = inner.replace(")","");
				string sm = domaths(x, y, inner,tbldat);
				print("tblfm: result = %s\n",sm);
				o = o.splice(ii,(oo + ii),sm);
				print("tblfm: spliced expression = %s\n",o);
			}
			z += 1;
		}
		if(o != null && o.strip() != "") { return o; }
	}
	return e;
}
string dolisp (int x, int y, string e, string[,] tbldat) {
	string o = e;
	int ii = e.index_of("'(") + 1;
	int oo = -1;
	int oc = 0;
	int cc = 0;
	for (int h = 0; h < e.length; h++) {
		if (e[h] == '(') { 
			if (h == ii) { oc = 1; } else { oc += 1; }
		}
		if (e[h] == ')') { 
			oc -= 1; 
			oo = h;
			if ( oc == 0 ) { break; } 
		}
	}
	o = e.substring(ii,oo);
	print("elisp: outer lisp expression is %s\n",o);
	int z = 0;
	while (o.contains("(")) {
		if (z > 20) { break; }
		ii = o.last_index_of("(");
		string m = o.substring(ii);
		oo = m.index_of(")") + 1;
		print("elisp: \tinner starts at %d, ends at %d\n",ii,oo);
		if (oo != -1) {
			string inner = o.substring(ii,oo);
			inner = replacerefs(x, y, inner, tbldat);
			print("elisp: \tinner lisp expression: %s\n",inner);
			string em = evallisp(x,y,inner,tbldat);
			if ( em == inner ) { break; }
			o = o.splice(ii,(oo + ii),em);
			o = o.replace("\"","");
			print("elisp: \tspliced expression = %s\n",o);
		} else { break; }
		z += 1;
	}
	print("\n");
	return o;
}

void main() {
	int64 ofmts = GLib.get_real_time();
	string[,] dat;
	string orgtbl = """| AA     | BB    | CC     | DD       |\n
|--------+-------+--------+----------|\n
| 68.0   | 39.47 | 128.15 | 337.59   |\n
| 403.88 | 16.21 | 117.03 | -9.0     |\n
| 5.8    | 14.73 | 58.1   | 107.64   |\n
|--------+-------+--------+----------|\n
|        |       |        |          |""";

	dat = orgtodat(orgtbl);
	string theformula = "@>$4=((vsum(@I$4..@>>>$4) / 1000.0 ) *  20.0);%.2f\n@>$2='(format \"%s_%f\" (downcase @1$2) @>>>$1)\n@>$1='(min @4$2 (max @3 @5))\n@>$3=@4$1-((@4$3 / @4$4) + 0.5)\n@1$2='(concat \"2_\" @1$2)\n@1$3 = '(abs @4$4) + '(org-sbe \"x\")";
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
				print("target row: %d (%s)",r,rs);
				string cs = ep[0].substring((oo + 1));
				c = getrefindex(cs,dat);
				print(", target col: %d, (%s)\n",c,cs);
				//ep[1] = replacerefs(r, c, ep[1], dat);
				bool skipfm = false;
// elisp 1st
				while (ep[1].contains("'(")) {
					print("elisp: lisp expression is %s\n",ep[1]);
					//ep[1] = dolisp(r,c,ep[1],dat);
					string o = ep[1];
					int qii = ep[1].index_of("'(") + 1;
					int qoo = -1;
					int oc = 0;
// match brace of elisp
					ep[1] = ep[1].splice((qii - 1),qii," ");
					print("elisp: spliced comma: %s\n",ep[1]);
					for (int h = qii; h < o.length; h++) {
						if (o[h] == '(') { 
							if (h == qii) { oc = 1; } else { oc += 1; }
						}
						if (o[h] == ')') { 
							oc -= 1; 
							qoo = h;
							if ( oc == 0 ) { break; } 
						}
					}
					print("elisp outer starts at %d, ends at %d\n",qii,qoo);
// isolate elisp
					o = ep[1].substring(qii,(qoo - (qii - 1)));
					print("elisp: outer lisp expression is %s\n",o);
					int z = 0;
// sub-expressions
					while (o.contains("(")) {
						if (z > 20) { break; }
						int eii = 0;
						int eoo = -1;
						eii = o.last_index_of("(");
						string m = o.substring(eii);
						eoo = m.index_of(")") + 1;
						print("elisp: \tinner starts at %d, ends at %d\n",eii,eoo);
						if (eoo != -1) {
							string inner = o.substring(eii,eoo);
							inner = replacerefs(r, c, inner, dat);
							print("elisp: \tinner lisp expression: %s\n",inner);
							string em = evallisp(r,c,inner,dat);
							if ( em == inner ) { 
								em = em.replace("(",""); em = em.replace(")","");
								em = "ERROR: unknown function %s".printf(em); 
							}
							//em = em.replace("'","");
							o = o.splice(eii,(eoo + eii),em);
							o = o.replace("\"","");
							print("elisp: \tspliced expression = %s\n",o);
						} else { break; }
						z += 1;
					}
					print("\n");
					ep[1] = ep[1].splice(qii,qoo+1,o);
				}
// catch outer refs
				if (ep[1].contains("@") || ep[1].contains("$")) {
					if (ep[1][0] != '(') { ep[1] = "(%s)".printf(ep[1]); }
				}
// maths
				//ep[1] = dotblfm(r,c,ep[1],dat);
				if ( ep[1].strip() != "") {
					string o = ep[1];
					int z = 0;
					int tii = -1;
					int too = -1;
					string inner = ep[1];
					while (o.contains("(")) {
						if (z > 50) { break; }
						tii = o.last_index_of("(");
						string m = o.substring(tii);
						too = m.index_of(")") + 1;
						inner = o.substring(tii,too);
						print("tblfm: inner expression: %s\n",inner);
						if (inner.contains("..")) {
							m = o.substring(0,tii);
							//print("before expression : %s\n",m);
							double  sm = dosum(inner,dat);
							tii = m.last_index_of("vsum");
							print("tblfm: sum = %f\n",sm);
							o = o.splice(tii,(too + tii + 4),"%f".printf(sm));
							print("tblfm: spliced expression = %s\n",o);
						}
						if (inner.contains("/") || inner.contains("*") || inner.contains("+") || inner.contains("-")){
							inner = inner.replace("(",""); inner = inner.replace(")","");
							string sm = domaths(r, c, inner, dat);
							print("tblfm: result = %s\n",sm);
							o = o.splice(tii,(too + tii),sm);
							print("tblfm: spliced expression = %s\n",o);
						}
						if (o == ep[1]) { o = "ERROR: unknown function %s".printf(o); break; }
						z += 1;
					}
					if(o != null && o.strip() != "") { ep[1] = o; }
				}
// formatting
				if ( ep[1].strip() != "") {
					print("checking formula val type: %s\n",ep[1]);
					if (ep[1].contains(";")) {
						fm = doformat(ep[1]);
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
}
