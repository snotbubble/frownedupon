// parse and run org tblfm expressions
// by c.p.brown, 2023
//
// todo next: handle whole row/col formulae, then finish elisp functions

bool spew;
string[,] orgtodat (int ind, string org) {
	int64 odtts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	string[,] dat = {{""}};
	string[] rr = org.split("\n");
	if (rr[0].has_prefix("|")) {
		int ii = rr[0].index_of("|");
		int oo = rr[0].last_index_of("|");
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
	int64 odtte = GLib.get_real_time();
	if (spew) { print("%sorgtodat took %f microseconds\n",tabs,((double) (odtte - odtts)));}
	return dat;
}
string reorgtable (int ind, string[,] dat) {
	int64 reots = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
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
	int64 reote = GLib.get_real_time();
	if (spew) { print("%sreorgtable took %f microseconds\n",tabs,((double) (reote - reots)));}
	return o;
}
// TODO: handle pre-trimmed input...
int getrefindex (int ind, string r, string[,] dat) {
	int64 idxts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	int o = 0;
	if (r != null && r.strip() != "") {
		if (spew) { print("%sgetrefindex: input is %s\n",tabs,r); }
		string s = r;
		s.canon("1234567890<>I",'.');
		int oo = s.index_of(".");
		if (oo > 0) {
			s = s.substring(0,oo);
			switch (s.get_char(0)) {
				case '>': if (spew) { print("%s\tget prev ref (>)...\n",tabs); } o = (dat.length[0] - (s.split(">").length - 1)); break;
				case '<': if (spew) { print("%s\tget next ref (<)...\n",tabs); } o = s.split("<").length; break;
				case 'I': 
					if (spew) { print("%s\tget hline ref (I)...\n",tabs); }
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
	if (spew) { print("%sgetrefindex: zero-based cell ref is %d\n",tabs,o); }
	int64 idxte = GLib.get_real_time();
	if (spew) { print("%sgetrefindex: took %f microseconds\n",tabs,((double) (idxte - idxts)));}
	return o;
}
// separate subtraction (a - b) from negative (-a)
string subminus (int ind, string s) {
	int64 pusts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
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
	int64 puste = GLib.get_real_time();
	if (spew) { print("%ssubminus took %f microseconds\n",tabs,((double) (puste - pusts)));}
return o;
}
string replacerefs (int ind, int myr, int myc, string inner, string[,] tbldat) {
	int64 refts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	if (inner != null && inner.strip() != "") {
		if (inner.contains("@") || inner.contains("$")) {
			if (spew) { print("%sreplacerefs: input is %s\n",tabs,inner); }
			string s = inner;
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
							if(spew) { print("%s\tr = %d, c = %d\n",tabs,r,c); }
							s = s.splice(int.min(rc[0],rc[1]),h,tbldat[r,c]);
							if (spew) { print("%sreplacerefs: spliced expression: %s\n",tabs,s); }
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
						c = getrefindex((ind + 1),cs, tbldat);
						//print("\tevallisp: \t\tc = %d\n",c);
					}
					if (t[h] == '@') {
						string rs = t.substring((h + 1));
						//print("\tevallisp: \t\trs = %s\n",rs);
						rc[0] = h;
						r = getrefindex((ind + 1),rs, tbldat);
						//print("\tevallisp: \t\tr = %d\n",r);
					}
				}
				y += 1;
			}
			int64 refte = GLib.get_real_time();
			if (spew) { print("%sreplacerefs took %f microseconds\n",tabs,((double) (refte - refts)));}
			return s;
		}
	}
	int64 refte = GLib.get_real_time();
	if (spew) { print("%sreplacerefs took %f microseconds\n",tabs,((double) (refte - refts)));}
	return inner;
}
string evalmaths (int ind, int myr, int myc, string inner, string[,] tbldat) {
	int64 mthts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	string o = inner;
	string[] ops = {"*", "/", "+", "!"};
	if (inner != null && inner.strip() != "") {
		if (spew) { print("%sdomaths input .....: %s\n",tabs,inner); }
		string s = inner;
		if (inner.contains("@") || inner.contains("$")) {
			s = replacerefs((ind + 1),myr, myc, inner, tbldat);
		}
		if (s.contains("-")) {
			s = subminus((ind + 1),s); s = s.replace("-"," -");
		}
		if (spew) { print("%sdomaths expression : %s\n",tabs,s); }
		int y = 0;
		foreach (string x in ops) {
			//if (s.contains(x)) {
			while (s.contains(x)) {
				//print("domaths: \texpression contains %s\n",x);
				if (y > 10) { break; }
				double sm = 0.0;
				string t = s; 
				switch (x) {
					case "*": t.canon("1234567890.*-",'_'); break;
					case "/": t.canon("1234567890./-",'_'); break;
					case "+": t.canon("1234567890.+-",'_'); break;
					case "!": t.canon("1234567890.!-",'_'); break;
					default:  t.canon("1234567890.",'_'); break;
				}
				//print("domaths: \ts.canon: %s\n",t);
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
						} else { print("%sERROR: %s or %s are not float",tabs,sp[0],sp[1]); break; }
					} else { print("%sERROR: %s or %s are not float",tabs,sp[0],sp[1]); break; }
					//print("domaths: s.length: %d\n",s.length);
					//print("domaths: \tsplicing from %d to %d\n",aii,oo);
					if (aii >= 0 && aii < s.length && aii < oo) {
						if (oo > aii && oo <= s.length) {
							s = s.splice(aii,oo,"%f".printf(sm));
							print("%sdomaths splice ....: %s\n",tabs,s);
						}
					}
					y += 1;
				} else { break; }
			}
		}

		//}
		o = s;
	}
	int64 mthte = GLib.get_real_time();
	if (spew) { print("%sdomaths took %f microseconds\n",tabs,((double) (mthte - mthts)));}
	return o;
}
string doformat (int ind, string n) {
	int64 frmts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	if (n != null && n != "") {
		if (spew) { print("%sdoformat: input is %s\n",tabs,n); }
		string[] np = n.split(";");
		if (np.length == 2) {
			if (np[0] != "" && np[1] != "") {
				string h = np[1].printf(double.parse(np[0]));
				int64 frmte = GLib.get_real_time();
				if (spew) { print("%sdoformat took %f microseconds\n",tabs,((double) (frmte - frmts)));}
				return h;
			}
		}
	}
	int64 frmte = GLib.get_real_time();
	if (spew) { print("%sdoformat took %f microseconds\n",tabs,((double) (frmte - frmts)));}
	return n;
}
string evallisp (int ind, int myr, int myc, string instr, string[,] tbldat) {
	int64 lspts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	string inner = instr;
	if (inner != null && inner.strip() != "") {
		if (spew) { print("%sevallisp: input is %s\n",tabs,inner); }
		int ic = 1;
		int ii = -1;
		if (inner.contains("format")) { 
			if (spew) { print("%s\tformat...\n",tabs); }
			inner = inner.replace("format","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			int ptl = 0;
			string[] k = {};
			foreach (string g in pts) { if (g.strip() != "") { ptl += 1; k += g.strip(); } }
			if (k.length > 1 && k[0].contains("%")) {
				if (spew) { print("%s\t\tgetting tokens in %s\n",tabs,k[0]); }
				int n = 1;
				int ival = 0;
				double dval = 0.0;
				k[0] = k[0].replace("%","%%");
				int y = 0;
				while (k[0].contains("%")) {
					if (y > 10) { break; }
					ii = k[0].index_of("%");
					string tk = k[0].substring(ii,3);
					if (strcmp(tk,"%%d") == 0) {
						if (int.try_parse(k[n],out ival)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							if (spew) { print("%s\t\tspliced format: %s\n",tabs,k[0]); }
							n += 1;
						} else { 
							int64 lspte = GLib.get_real_time();
							if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
							return "ERROR: format arg %d not an int".printf(n); 
						}
					}
					if (strcmp(tk,"%%f") == 0) {
						if (double.try_parse(k[n],out dval)) {
							k[0] = k[0].splice(ii,(ii+3),k[n]);
							if (spew) { print("%s\t\tspliced format: %s\n",tabs,k[0]); }
							n += 1;
						} else { 
							int64 lspte = GLib.get_real_time();
							if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
							return "ERROR: format arg %d not an int".printf(n); 
						}
					}
					if (strcmp(tk,"%%s") == 0) {
						k[0] = k[0].splice(ii,(ii+3),k[n]);
						if (spew) { print("%s\t\tspliced format: %s\n",tabs,k[0]); }
						n += 1;
					}
					y += 1;
				}
				int64 lspte = GLib.get_real_time();
				if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
				return k[0];
			}
		}
		if (inner.contains("make-string")) {
// (make-string 5 ?x)
			if (spew) { print("%s\tmake-string...\n",tabs); }
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
				int64 lspte = GLib.get_real_time();
				if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
				return string.joinv(" ",pts);
			}
		}
		if (inner.contains("string")) { }
		if (inner.contains("substring")) { }
		if (inner.contains("concat")) { 
// (concat "s" "s")
			if (spew) { print("%s\tconcat...\n",tabs); }
			inner = inner.replace("concat","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.split(" ");
			if (pts.length > 0 && pts[0] != "") {
				for (int h = 0; h < pts.length; h++) {
					string hh = pts[h].replace("\"","").strip();
					pts[h] = hh;
				}
				int64 lspte = GLib.get_real_time();
				if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
				return string.joinv("",pts);
			}
		}
		if (inner.contains("downcase")) { 
// (downcase "s")
			if (spew) { print("%s\tdowncase...\n",tabs); }
			inner = inner.replace("downcase","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			int64 lspte = GLib.get_real_time();
			if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
			return inner.down(); 
		}
		if (inner.contains("upcase")) { 
// (upcase "s")
			if (spew) { print("%s\tupcase...\n",tabs); }
			inner = inner.replace("upcase","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			int64 lspte = GLib.get_real_time();
			if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
			return inner.up(); 
		}
// number
		if (inner.contains("abs")) { 
// (abs -1)
			if (spew) { print("%s\tabs...\n",tabs); }
			inner = inner.replace("abs","");
			inner = inner.replace("(","");
			inner = inner.replace(")","").strip();
			string[] pts = inner.strip().split(" ");
			if (pts.length == 1 && pts[0] != "") {
				double v = 0.0;
				if (double.try_parse(pts[0], out v)) {
					v = v.abs();
					int64 lspte = GLib.get_real_time();
					if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
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
// (min 1 2 3...)
			if (spew) { print("%s\tmin...\n",tabs); }
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
					int64 lspte = GLib.get_real_time();
					if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
					return "%f".printf(v);
				}
			}
		}
		if (inner.contains("max")) { 
// (max 1 2 3...)
			if (spew) { print("%s\tmax...\n",tabs); }
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
					int64 lspte = GLib.get_real_time();
					if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
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
	int64 lspte = GLib.get_real_time();
	if (spew) { print("%sevallisp took %f microseconds\n",tabs,((double) (lspte - lspts)));}
	return instr;
}
double dosum (int ind, int myr, int myc, string inner, string[,] tbldat) {
	int64 sumts = GLib.get_real_time();
	string tabs = ("%*s").printf(ind," ").replace(" ","\t");
	double sm = 0.0;
	if (inner != null && inner.strip() != "") {
		if (spew) { print("%sdosum: %s\n",tabs,inner); }
		string[] sp = inner.split("..");
		if (sp.length == 2) {
			if (sp[0].strip() != "" && sp[1].strip() != "") {
				int[] coords = {-1,-1,-1,-1};
				for (int x = 0; x < 2; x++) {
					int b = 0;
					int[] rc = {-1,-1};
					int y = 0;
					int r = myr;
					int c = myc;
					while (sp[x].contains("@") || sp[x].contains("$")) {
						if (y > 200) { print("ERROR: reference string stuck in the loop: %s\n",sp[x]); break; }
						string t = sp[x]; t.canon("$@1234567890<>I",'.');
						for (int h = b; h < t.length; h ++) {
							if (t[h] == '.' || (h == t.length - 1)) {
								if ((rc[0] + rc[1]) != -2) {
									if (rc[0] == -1) { r = myr; rc[0] = 99999; }
									if (rc[1] == -1) { c = myc; rc[1] = 99999; }
									coords[(x+x)] = r; coords[(1+(x+x))] = c;
									sp[x] = sp[x].splice(int.min(rc[0],rc[1]),h,"");
									if (spew) { print("%sdosum: part%d row = %d, col = %d\n",tabs,x,r,c); }
								}
								rc = {-1,-1};
								b = ((h + 1) - (t.length - sp[x].length));
								r = myr; c = myc;
								break;
							}
							if (t[h] == '$') { 
								string cs = t.substring((h+1));
								rc[1] = h;
								c = getrefindex((ind + 1),cs, tbldat);
							}
							if (t[h] == '@') {
								string rs = t.substring((h + 1));
								rc[0] = h;
								r = getrefindex((ind + 1),rs, tbldat);
							}
						}
						y += 1;
					}
				}
				if (spew) { print("%sdosum: zero-based cell refs...\n",tabs); }
				if (spew) { print("%s\trow1=%d, col1=%d\n%s\trow2=%d, col2=%d\n",tabs,coords[0],coords[1],tabs,coords[2],coords[3]); }
				if (coords[0] == coords[2]) {
					for (int i = coords[1]; i <= coords[3]; i++) {
						double dd = 0.0;
						if (double.try_parse(tbldat[coords[0],i])) {
							if ( dd != 0.0) { sm += dd; }
						}
					}
					if (spew) { print("%s\thsum = %f\n",tabs,sm); }
				}
				if (coords[1] == coords[3]) {
					for (int i = coords[0]; i <= coords[2]; i++) { 
						double dd = 0.0;
						if (double.try_parse(tbldat[i,coords[1]],out dd)) {
							if ( dd != 0.0) { sm += dd; }
						}
					}
					if (spew) { print("%s\tvsum = %f\n",tabs,sm); }
				}
			}
		}
	}
	int64 sumte = GLib.get_real_time();
	if (spew) { print("%sdosum took %f microseconds\n",tabs,((double) (sumte - sumts)));}
	return sm;
}
string doelisp (int ind, int r, int c, string e, string[,] tbldat) { 
	string ret = e;
	int y = 0;
	while (ret.contains("'(")) {
		if (spew) { print("\t\telisp: lisp expression is %s\n",e); }
		if (y > 200) { print("ERROR: expression stuck in a loop: %s\n",e); break; }
		string o = e;
		int qii = e.index_of("'(") + 1;
		int qoo = -1;
		int oc = 0;
// match brace of elisp
		ret = ret.splice((qii - 1),qii," ");
		if (spew) { print("\t\telisp: spliced comma: %s\n",e); }
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
// isolate elisp
		o = e.substring(qii,(qoo - (qii - 1)));
		if (spew) { print("\t\telisp: outer lisp expression is %s\n",o); }
		int z = 0;
// sub-expressions
		while (o.contains("(")) {
			if (z > 200) { print("\nERROR: expression stuck in the elisp inner loop: %s\n\n",o); break; } // incasement
			if (spew) { print("\t\t\telisp inner: iteration %d\n",z); }
			int eii = 0;
			int eoo = -1;
			eii = o.last_index_of("(");
			string m = o.substring(eii);
			eoo = m.index_of(")") + 1;
			if (eoo != -1) {
				string inner = o.substring(eii,eoo);
				if (inner.contains("@") || inner.contains("$")) {
					inner = replacerefs(4,r, c, inner, tbldat);
				}
				if (spew) { print("\t\t\telisp inner: lisp expression: %s\n",inner); }
				string em = evallisp(4,r,c,inner,tbldat);
				if ( em == inner ) { 
					em = em.replace("(",""); em = em.replace(")","");
					em = "ERROR: unknown function %s".printf(em); 
				}
				o = o.splice(eii,(eoo + eii),em);
				o = o.replace("\"","");
				if (spew) { print("\t\t\telisp inner: spliced expression = %s\n",o); }
			} else { break; }
			z += 1;
		}
		ret = ret.splice(qii,qoo+1,o);
	}
	return ret;
}
string domaths (int ind, int r, int c, string e, string[,] tbldat) {
	string ret = e;
	if ( e.strip() != "") {
		string o = e;
		int z = 0;
		int tii = -1;
		int too = -1;
		string inner = e;
		if (spew) { print("\ttblfm checking expression: %s\n",e); }
		while (o.contains("(")) {
			if (z > 200) { print("\nERROR: expression stuck in the tblfm inner loop: %s\n\n",o); break; }
			tii = o.last_index_of("(");
			string m = o.substring(tii);
			too = m.index_of(")") + 1;
			inner = o.substring(tii,too);
			if (spew) { print("\t\ttblfm: inner expression: %s\n",inner); }
			if (inner.contains("..")) {
				m = o.substring(0,tii);
				double  sm = dosum(3,r,c,inner,tbldat);
				tii = m.last_index_of("vsum");
				if (spew) { print("\t\ttblfm: sum = %f\n",sm); }
				o = o.splice(tii,(too + tii + 4),"%f".printf(sm));
				if (spew) { print("\t\ttblfm: spliced expression = %s\n",o); }
			}
			if (inner.contains("/") || inner.contains("*") || inner.contains("+") || inner.contains("-")){
				inner = inner.replace("(",""); inner = inner.replace(")","");
				string sm = evalmaths(3,r, c, inner, tbldat);
				if (spew) { print("\t\ttblfm: result = %s\n",sm); }
				o = o.splice(tii,(too + tii),sm);
				if (spew) { print("\t\ttblfm: spliced expression = %s\n",o); }
			}
			if (o == e) { o = "ERROR: unknown function %s".printf(o); break; }
			z += 1;
		}
		if(o != null && o.strip() != "") { ret = o; }
	}
	return ret;
}

void main() {
	int64 ofmts = GLib.get_real_time();
	spew = true;
	string[,] dat;
	string orgtbl = """| AA     | BB    | CC     | DD       |\n
|--------+-------+--------+----------|\n
| 68.0   | 39.47 | 128.15 | 337.59   |\n
| 403.88 | 16.21 | 117.03 | -9.0     |\n
| 5.8    | 14.73 | 58.1   | 107.64   |\n
|--------+-------+--------+----------|\n
|        |       |        |          |""";

	dat = orgtodat(0,orgtbl);
	string theformula = "@>$4=((vsum(@1$4..@>>>$4) / 1000.0 ) *  20.0);%.2f\n@>$2='(format \"%s_%f\" (downcase @1$2) @>>>$1)\n@>$1='(min @4$2 (max @3 @5))\n@>$3=@4$1-((@4$3 / @4$4) + 0.5)\n@1$2='(concat \"2_\" @1$2)\n@1$3 = '(abs @4$4) + '(org-sbe \"x\")\n$4=($1*$2);%.2f\n@1='(concat \"[\" @1 \"]\")";
	//string e = theformula;
	// we need 9.0846 from the above
	string[] xprs = theformula.split("\n");
	int ii = 0;
	int oo = 0;
	int r = 0;
	int c = 0;
	string fm = "";
	foreach (string e in xprs) {
		if (spew) { print("reading formula : %s\n",e); }
		string[] ep = e.split("=");
		ii = -1;
		oo = -1;
		r = -1;
		c = -1;
		fm = "";
		if (ep.length == 2) {
			ep[0] = ep[0].strip();
			ep[1] = ep[1].strip();
			if (ep[0] != "" && ep[1] != "") {
// TODO:
// handle whole row/col target loops, eg: $3=($1*$2) -> for i in rows { cell[i,2] = cell[i,0] * cell[i,1] }
				if (spew) { print("\tget target cell...\n"); }
				ii = ep[0].index_of("@");
				oo = ep[0].index_of("$");
				print("index_of @ is %d, index_of $ is %d\n",ii,oo);
				if (ii > -1) {
					string rs = ep[0].substring((ii+1));
					r = getrefindex(2,rs,dat);
					if (spew) { print("\ttarget row: %d (%s)\n",r,rs); }
				}
				if (oo > -1) {
					string cs = ep[0].substring((oo + 1));
					c = getrefindex(2,cs,dat);
					if (spew) { print("\ttarget col: %d, (%s)\n",c,cs); }
				}
// target is valid
				if ((r + c) != -2) {
// eval a row loop
					if (c == -1) {
						print("\tlooping over columns...\n");
						for (int i = 0; i < dat.length[1]; i++) {
							string ie = ep[1];
							if (i > 100) { break; }
							c = i;
							if (dat[r,c].has_prefix("--") == false) {
								ie = doelisp(2,r,c,ie,dat);
								if (ie.contains("@") || ie.contains("$")) {
									if (ie[0] != '(') { ie = "(%s)".printf(ie); }
								}
								ie = domaths(2,r,c,ie,dat);
								if ( ie.strip() != "") {
									if (ie.contains(";")) {fm = doformat(0,ie);} else {fm = ie;}
									if (spew) { print("\tformula changed dat[%d,%d] from \"%s\" to %s\n\n",r,c,dat[r,c],fm); }
									dat[r,c] = fm;
								}
							}
						}
					} else {
// eval a column loop
						if (r == -1) {
							print("\tlooping over rows...\n");
							for (int i = 0; i < dat.length[0]; i++) {
								string ie = ep[1];
								if (i > 100) { break; }
								r = i;
								if (dat[r,c].has_prefix("--") == false) {
									ie = doelisp(2,r,c,ie,dat);
									if (ie.contains("@") || ie.contains("$")) {
										if (ie[0] != '(') { ie = "(%s)".printf(ie); }
									}
									ie = domaths(2,r,c,ie,dat);
									if ( ie.strip() != "") {
										if (ie.contains(";")) {fm = doformat(0,ie);} else {fm = ie;}
										if (spew) { print("\tformula changed dat[%d,%d] from \"%s\" to %s\n\n",r,c,dat[r,c],fm); }
										dat[r,c] = fm;
									}
								}
							}
						} else {
// eval once for a cell...
							ep[1] = doelisp(2,r,c,ep[1],dat);
							if (ep[1].contains("@") || ep[1].contains("$")) {
								if (ep[1][0] != '(') { ep[1] = "(%s)".printf(ep[1]); }
							}
							ep[1] = domaths(2,r,c,ep[1],dat);
							if ( ep[1].strip() != "") {
								if (ep[1].contains(";")) {fm = doformat(0,ep[1]);} else {fm = ep[1];}
								if (spew) { print("\tformula changed dat[%d,%d] from \"%s\" to %s\n\n",r,c,dat[r,c],fm); }
								dat[r,c] = fm;
							}
						}
					}
					if (spew) { print("\n%s\n",reorgtable(0,dat)); }
					if (spew) { print("\n#+TBLFM: %s\n",theformula); }
					int64 ofmte = GLib.get_real_time();
					if (spew) { print("\ntable formula took %f microts\n\n",(((double) (ofmte - ofmts))/1000000.0) ); }
				}
			}
		}
	}
}
