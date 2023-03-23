// my_untiteld_program_for_2023
// by c.p.brown 2022

// view modes:
//
//  relationship graph
//  dumb mindmap
//  follows orgmode item hierarchy
//
//  +------------------------------+------------+
//  |  graph                       | native org |
//  +------------------------------+------------+
//  |  +--------------+            | * one      |
//  |  |      one     |            | ** two     |
//  |  +--------------+            | *** three  |
//  |          |                   | *** four   |
//  |  +--------------+            |            |
//  |  |      two     |            |            |
//  |  +--------------+            |            |
//  |          |      \            |            |
//  |          |       \           |            |
//  |          |        \          |            |
//  |          |        +--------+ |            |
//  |  +-------------+  |  four  | |            |
//  |  |    three    |  +--------+ |            |
//  |  +-------------+             |            |
//  +------------------------------+------------+
//
//
//  process graph
//  more like an ETL tool
//  Follows variables and properties, doesn't care about article hierarchy.
//
//  the main problem with a process graph is how to deal with multiple elements in one article,
//  natively orgmode behaves like this:
//    +------------------------------------------------------------------------------------+-----------------------------+
//    | graph                                                                              | native org                  |
//    +------------------------------------------------------------------------------------+-----------------------------+
//    |  +-------------------------------------------------------------------------+       | * my article                |
//    |  | my article:subnet                                                       |]      |   :PROPERTIES:...           |
//    |  +-------------------------------------------------------------------------+       |   #+BEGIN_SRC python...     |
//    |  |  +-----------------------+                                              |       |   #+NAME: graph1            |
//    |  |  | my_article:properties |                                              |       |   #+RESULTS:...             |
//    |  |  +-----------------------+                                              |       |   article                   |
//    |  |  +-------------------+                                                  |       |   goes here                 |
//    |  |  | my_article:graph1 |                                                  |       |   and more text             |
//    |  |  +===================+                                                 ┌|       |   #+ATTR_LATEX...           |
//    |  |  | graph1_result     |]================================================│|       |   fancie text               |
//    |  |  +-------------------+                                                 │|       |   #+ATTR_LATEX...           |
//    |  |    +------------------+                                                │|       |   back to normal text       |
//    |  |    | my_article:text1 |                                                │|       |   #+BEGIN_SRC python...     |
//    |  |    +------------------+                                                │|       |   #+NAME: table1            |
//    |  |    | text1            |]===============================================│|       |   #+RESULTS:...             |
//    |  |    +------------------+                                                │|       |   and final texts           |
//    |  |     +------------------+                                               │|       |                             |
//    |  |     | my_article:attr1 |                                               │|       |                             |
//    |  |     +------------------+                                               │|       |                             |
//    |  |     | attr1            |]==============================================│|       |                             |
//    |  |     +------------------+                                               │|       |                             |
//    |  |      +------------------+                                              │|       |                             |
//    |  |      | my_article:text2 |                                              │|       |                             |
//    |  |      +------------------+                                              │|       |                             |
//    |  |      | text2            |]=============================================│|       |                             |
//    |  |      +------------------+                                              │|       |                             |
//    |  |       +------------------+                                             │|       |                             |
//    |  |       | my_article:attr2 |                                             │|       |                             |
//    |  |       +------------------+                                             │|       |                             |
//    |  |       | attr2            |]============================================│|       |                             |
//    |  |       +------------------+                                             │|       |                             |
//    |  |        +------------------+                                            │|       |                             |
//    |  |        | my_article:text3 |                                            │|       |                             |
//    |  |        +------------------+                                            │|       |                             |
//    |  |        | text3            |]===========================================│|       |                             |
//    |  |        +------------------+                                            │|       |                             |
//    |  |         +-------------------+                                          │|       |                             |
//    |  |         | my_article:table1 |                                          │|       |                             |
//    |  |         +-------------------+                                          │|       |                             |
//    |  |         | table1_result     |]=========================================│|       |                             |
//    |  |         +-------------------+                                          │|       |                             |
//    |  |          +------------------+                                          │|       |                             |
//    |  |          | my_article:text4 |                                          │|       |                             |
//    |  |          +------------------+                                          │|       |                             |
//    |  |          | text4            |]=========================================│|       |                             |
//    |  |          +------------------+                                          └|       |                             |
//    |  +-------------------------------------------------------------------------+       |                             |
//    |                                                                                    |                             |
//    +------------------------------------------------------------------------------------+-----------------------------+
//  Where each 'dangling' item is connected to the output in the sequence they are written.
//  For a process graph we have to use a subnet for the article contents, with a generic subnet output that can be used
//  to collect node output in sequence.
//
//  This can be optimized with a new link type: [[val:variable]] :
//    +------------------------------------------------------------------------------------+-----------------------------+
//    | graph                                                                              | native org                  |
//    +------------------------------------------------------------------------------------+-----------------------------+
//    |  +-------------------------------------------------------------------------+       | * my article                |
//    |  | my article:subnet                                                       |       |   :PROPERTIES:...           |
//    |  +-------------------------------------------------------------------------+       |   #+BEGIN_SRC python...     |
//    |  |  +-----------------------+                                              |       |   #+NAME: graph1_result     |
//    |  |  | my_article:properties |                                              |       |   #+RESULTS:...             |
//    |  |  +-----------------------+                                              |       |   #+BEGIN_SRC python...     |
//    |  |  +-------------------+                      +-----------------+         |       |   #+NAME: table1_result     |
//    |  |  | my_article:graph1 |                      | my_article:text |         |       |   #+RESULTS...              |
//    |  |  +===================+                      +-----------------+         |       |   article                   |
//    |  |  | graph1_result     |]════════════════════[| graph1_result   |         |       |   goes here                 |
//    |  |  +-------------------+                      +-----------------+         |       |   and more text             |
//    |  |                                             +-----------------+         |       |   [[val:graph1_result]]     |
//    |  |                                        ╔═══[| table1_result   |         |       |   more text                 |
//    |  |                                        ║    +-----------------+        ┌|       |   #+ATTR_ATEX...            |
//    |  |                                        ║    | text            |]═══════│|       |   fancie text               |
//    |  |                                        ║    +-----------------+        └|       |   #+ATTR_LATEX...           |
//    |  |                                        ║                                |       |   back to normal text       |
//    |  |      +-------------------+             ║                                |       |   [[val:table1]]            |
//    |  |      | my_article:table1 |             ║                                |       |   final text                |
//    |  |      +-------------------+             ║                                |       |                             |
//    |  |      | table1_result     |]════════════╝                                |       |                             |
//    |  |      +-------------------+                                              |       |                             |
//    |  |                                                                         |       |                             |
//    |  +-------------------------------------------------------------------------+       |                             |
//    |                                                                                    |                             |
//    +------------------------------------------------------------------------------------+-----------------------------+
//  Where ATTRs are considered text, since they inject text on export anyway. 
//  However [[val:varname]] doesn't exist in orgmode!
//  I saw a limited implementation of this by Tobias Zawada in 2018:
//  https://emacs.stackexchange.com/questions/46020/using-file-local-variables-in-org-mode
//
//  I'll have to make something that can also support:
//    #+NAME: var val
//    #+NAME: var
//    val
//    #+NAME: var
//    #+BEGIN_SRC...
//    #+NAME: var
//    #+RESULTS...
//    :PROPERTIES:
//    :VAR: val
//    :END:
//    # Local Variables:
//    # var: val
//  then somehow get it merged with orgmode... could take decades.
//
//  Anoter problem is layout: the coords can't be saved, nor any node/link styles, themes and templates
//  This is because the nodes aren't articles, but derrived from article elements, so lack their own properties.
//  There's a few choices:
//    1. Don't save any ui specific data and auto-layout, at risk of aggrivating users who expect their layout to be saved.
//    2. Use article-based nodes, save layout in properties and have self-intersecting i/o wiring in cases where variables 
//       are set and used within the same article. 
//       Shenzen i/o hd this same problem(exploit), where the cabling would go under the component.
//    3. Make articles with internal linkage a subnet. this seems to be the best compromise.
//
//
//  Option one: Auto layout based on data-flow, ignores articles, autolayout since there's no (reliable) storage for sub-items.
//  +--------------------------------------------------------------+----------------------------------------------------------+
//  | graph                                                        | native org                                               |
//  +--------------------------------------------------------------+----------------------------------------------------------+
//  |  +-------------+     +-----------+                           | * one                                                    |
//  |  | one:propbin |     | three:src |                           |   :PROPERTIES:                                           |
//  |  +-------------+     +===========+     +-----------------+   |   :ONE: 1                                                |
//  |  | ONE         |]===[| x | ONE   |     | two:article     |   |   :END:                                                  |
//  |  +-------------+     +===========+     +--------+--------+   | ** two                                                   |
//  |                      | result    |]===[| result | val    |   |    some text                                             |
//  |                      +-----------+     +--------+--------+   |    [[val:result]]                                        |
//  |                                        | text            |]  |    more text                                             |
//  |                                        +-----------------+   | *** three                                                |
//  |                                                              |     #+BEGIN_SRC rebol3 :var x=(org-entry-get nil "ONE")  |
//  |                                                              |     REBOL[]                                              |
//  |                                                              |     probe x                                              |
//  |                                                              |     #+END_SRC                                            |
//  |                                                              |     #+NAME: result                                       |
//  |                                                              |     #+RESULT:                                            |
//  |                                                              |     1                                                    |
//  +--------------------------------------------------------------+----------------------------------------------------------+
//
//  Option two: per-article nodes, but with messy internal patching in a stack.
//  +-------------------------------------------+----------------------------------------------------------+
//  | graph                                     | native org                                               |
//  +-------------------------------------------+----------------------------------------------------------+
//  |                   +--------------------+  | * one                                                    |
//  |                   | two                |  |   :PROPERTIES:                                           |
//  |                   +--------------------+  |   :ONE: 1                                                |
//  |  +-------------+  |  +--------------+  |  |   :END:                                                  |
//  |  | one         |  |  | two:src      |  |  | ** two                                                   |
//  |  +-------------+  |  +==============+  |  |    #+BEGIN_SRC :var x=(org-entry-get nil "ONE")...       |
//  |  | ONE         |]=|=[| x | ONE      |  |  |    #+NAME: result                                        |
//  |  +-------------+  |  +==============+  |  |    #+RESULT...                                           |
//  |                   |  | result       |]╗|  |    text                                                  |
//  |                   |  +--------------+ ║|  |    [[val:result]]                                        |
//  |                   |╔══════════════════╝|  |    moretext                                              |
//  |                   |║ +--------+-----+  |  |                                                          |
//  |                   |╚[| result | val |  |  |                                                          |
//  |                   |  +--------+-----+  |  |                                                          |
//  |                   |  | two:text     |]=|==|                                                          |
//  |                   |  +--------------+  |  |                                                          |
//  |                   +--------------------+  |                                                          |
//  |                                           |                                                          |
//  +-------------------------------------------+----------------------------------------------------------+
//
//  Option three: internal linkage shown as a subnet, revealed on zoom, 
//  article nodes use manual layout.
//  Zoomed-out:
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//  | graph                                                           | native org                                          |
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//  |                                                                 | * one                                               |
//  |  +-------------+    +--------------+                            |   :PROPERTIES:                                      |
//  |  | one         |    | two:subnet   |                            |   :ONE: 1                                           |
//  |  +-------------+    +--------------+                            |   :END:                                             |
//  |  | ONE         |]==[| x | ONE      |                            | ** two                                              |
//  |  +-------------+    +--------------+                            |    #+BEGIN_SRC :var x=(org-entry-get nil "ONE")...  |
//  |                     | text         |]==..                       |    #+NAME: result                                   |
//  |                     +--------------+                            |    #+RESULT...                                      |
//  |                                                                 |    text                                             |
//  |                                                                 |    [[val:result]]                                   |
//  |                                                                 |    moretext                                         |
//  |                                                                 |                                                     |
//  |                                                                 |                                                     |
//  |                                                                 |                                                     |
//  |                                                                 |                                                     |
//  |                                                                 |                                                     |
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//
//  Zoomed-in. 
//  Subnet uses a compact auto-layout on load, manual during session.
//  Double-tap subnet titlebar to expand it, double-tap on bg to return & frame subnet.
//  Can pan/zoom independently of container when expanded.
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//  | graph                                                           | native org                                          |
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//  |---------+         +------------------------------------------+  | * one                                               |
//  |         |         | two:subnet                               |  |   :PROPERTIES:                                      |
//  |         |         +------------------------------------------+  |   :ONE: 1                                           |
//  |         |         |                                          |  |   :END:                                             |
//  |         |         |                                          |  | ** two                                              |
//  |         |         |                                          |  |    #+BEGIN_SRC :var x=(org-entry-get nil "ONE")...  |
//  |---------+         |                                          |  |    #+NAME: result                                   |
//  |         |         |    +---------+                           |  |    #+RESULT...                                      |
//  |         |         |    | two:src |                           |  |    text                                             |
//  |         |─┐     ┌─|┐   +=========+      +--------------+     |  |    [[val:result]]                                   |
//  |         | │▔▔▔▔▔│ |│==[| x | ONE |      | two:text     |     |  |    moretext                                         |
//  |         |─┘▔▔▔▔▔└─|┘   +=========+      +--------+-----+     |  |                                                     |
//  |         |         |    | result  |]====[| result | val |     |  |                                                     |
//  |         |         |    +---------+      +--------+-----+    ┌|─┐|                                                     |
//  |---------+         |                     | text         |]===│| │|                                                     |
//  |                   |                     +--------------+    └|─┘|                                                     |
//  +-----------------------------------------------------------------+-----------------------------------------------------+
//
//
//  timeline
//  can flip orientation depending on aspect
//  detects and plots any dates, will duplicate as required, stacks overlap
//  it will optionally compress unused time to minimize scrolling
//  zooming will smoothly transition from years down to hours
//
//  +-------------------------------------------------+------------------------------------------+
//  | timeline                                        | native org                               |
//  +-------------------------------------------------+------------------------------------------+
//  |----------+   :    :    +-------------------+    | * one                                    |
//  |  one     |   :    :    |      three        |    |   SCHEDULED: <2023-10-16>--<2023-10-24>  |
//  |----------+   :    :    +-------------------+    | ** two                                   |
//  |    :    +------------------+     :    +----+    |    <2023-10-25>--<2023-10-28>            |
//  |    :    |       two        |     :    | t. |    |    DUE: <2023-10-31>                     |
//  |    :    +------------------+     :    +----+    | *** three                                |
//  +-------------------------------------------------+     :PROPERTIES:                         |
//  | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 01 |     :WHEN: <2023-10-28>--<2023-10-31>    |
//  +-------------------------------------------------+     :END:                                |
//  |               october                      | n. |                                          |
//  +-------------------------------------------------+------------------------------------------+
//
//  future views:
//     calendar	(likely)		Uses any dates same as timeline.
//     chart		(likely)		Uses any numeric vars/properties, optionally date if not a range.
//     webview		(likely)		View html in an embedded browser.
//     filterview	(likely)		Build filters as a list of commands, eg: include tag "pic"; exclude todo "[5_NOPE]";
//     spreadsheet	(eventually)	For org-tables and multiline results that have a delimiter like csv *must be lightning fast with millions of rows* (see Geometry spreadsheet in Sidefx Houdini).
//     map			(wouldbenice)	Uses any lat:lon data, or anything named 'address' or 'ADDRESS'.
//     shaderview   (wouldbenice)	View wgsl or vulkan shaders, useful for data-driven UIs, must have safe-mode tho.
//     pdfview		(dunnoyet)		View any compatible result in a pdf renderer, preferably native. Awful long-term project.
//     org			(unlikely)		An interactive CUA gtksourceview org buffer embedded in the program.
//
//  more on views:
//    views must work as standalone tools on native orgfiles 1st
//    views must have commandline args, eg: 
//      calendarview -i ./myorgfile --theme ./themes/sb_blue.theme --filter ./filters/upnext.flt
//      processview -i ./myorgfile --evalonly --node "postprocess:source" --cleartemps --log ./eval_log.txt
//		graphview -i ./myorgfile --selectnode "article one" --filter "excludetags [ "[0_WAIT]" "[5_NOPE]" ]" --theme ".node {font-size: clamp(20px,10.0vw,100px);}"
//    args can be either be command strings of files containg them
//    args must be consistent across all views
//    views can be loaded and unloaded by knoms at runtime
//    

using Gtk;

// anatomy

//  namevar
//    id			<-- namevar id
//    name			<-- namevar name string
//    value		<-- namevar value string
//    clients[]	<-- ids of nodes that use this namevar in ivars[]
//  article
//    id			<-- article id
//    nodes		<-- list of node ids, ordered as they were found in the orgfile
//    manbag		<-- random stuff found in the article that isn't a node, just put it here and append it to the article when writing back to org
//   node			<-- the discrete elements of an aritcle: propertybin, src_block, result_block, named items, contigious lines of plain text (incl. attrs) 
//     id			<-- node id
//     article		<-- article id
//     name		<-- the node name if its named, otherwise autonamed, eg: my_article_srcblock1
//     cargs[]		<-- args before colon args, eg: 'python' in #+BEGIN_SRC python :tangle ./wut.py
//     hargs[]		<-- args appended to the node header, if it exists
//     ivars[]		<-- ids of namevars found in header and value (code, text)
//     lvars[]		<-- local vars foud in header, name val pairs, these may be promoted to namevars in future (can wire them out), but naming becomes problematic
//     type		<-- controls what to do with the node
//     svalue		<-- the content of the node, eg: the source code in a src block, the text in pain text, the value of a name, always string
//     rvalue		<-- the contents of the next result if this is a srcblock
//  gtk
//  inputparamclass		<-- input port ui
//  localparamclass		<-- local variable params
//  articlenodeclass		<-- article node params
//  subnodeclass			<-- article element node params
//    entry name			
//    entry id				
//    toggle freeze		
//    toggle silent		
//    toggle enable			
//    droplist ctype		<-- hidden if not srcblock
//    droplist compile		<-- hidden if not srcblock
//    string args			<-- hidden if not srcblock
//    ivarparam[] inputs	<-- any reference to an external value gets a port
//    lvarparam[] locals	<-- any locally defined var gets a parameter
//    sourceview svalue	<-- hidden if its renaming an incoming variable
//    sourceview rvalue	<-- hidden of not srcblock 
//    nodefunction mynodeindex myarticleindex mynodetype

int		drwm;			// controls what drawingarea gets drawn when there's several of them

struct port {
	string	id;			// port id
	string	name;			// name of cargo
	string	owner;			// node/article id
	string	source;		// port id of cargo source, if it refers to a port name
	string	org;			// org syntax to backwash to orgmode, may be altered in this program
	int[]	pos;			// {x,y} position for rendering wires
	string	cargo;			// value of cargo, nill in relationship graph
}

struct article {
	string		id;		// uniuqe id, for this program only
	string		name;		// article name, should be unique, but org doesn't require it
	string[]	nodes;		// list of node ids found within this article
	string[]	ports;		// ports for wiring
//	string[]	todos		// TODO: list of todo tags
//	string[]	tags		// TODO: list of tag tags
//	string		priority	// TODO: priority tag
//	string		template;	// TODO: display template for node graph relationship view, internal use only
	string		manbag;	// other stuff that isn't any of the above, it gets appended to the article when writing back to org
}
struct narg {				//
	string	name;			// arg name, eg: 'tangle'
	string	value;			// arg value, eg: './file.ext'
}
struct node {					// 											// used for
	string		id;			// unique id									getting at this node's data by other nodes
	string		name;			// #+NAME name, property name, or auto			display
	string		type;			// property, namevar, srcblock, text			faster filtering, search
	string		article;		// the article this node belongs to			what subnet to render this in
	narg[]		nargs;			// header args									what to do on eval
	string[]	cmd;			// special instructions						hide/unhide ui, what to do on eval
	string[]	ports;			// unique ids of vars used by this node		inject/substitute port cargo into src before eval, tell renderer what to wire-up
	string		value;			// source, text, name value, property value	content
}

// wire
//   srcpos: source.pos
//   trgpos: target.pos

// port (i/o)
//   id: hash
//   owner: node id
//   wires[]: wires that ref this port
//   pos: render position for drawing
//   type: input, output
//   flags: one, accumulate


// parameter ui
//    +--------+--------------------+
//    | name   | mycode             |   this source block's name
//    +--------+--------------------+
//    | type   | [ srcblock ][▾]    |   
//    +--------|--------------------+
//    | freeze | [ ] off            |   don't pass-on cached result & block upstream eval
//    +--------+--------------------+
//    | silent | [ ] off            |   generate output
//    +--------+--------------------+
//    | bin    | [ auto ][▾]        |   don't recompile if the code hasn't been changed and the binary exists - needs changes to ob-lang files to make it work natively in org, hold-off on this for now
//    +--------+--------------------+
//    | vars            [+][-][▾][▴]|   add/remove/re-arrange vars in a list
//    +--------+--------------------+
//    | x      | "string"           |   local variable, same as :var x="string", what these do to the orgfile depends on node type
//    +--------+--------------------+
//    | y      | other_result       |   local variable using another code block, :var x=other_result
//    +--------+--------------------+
//    | z      | MYPROPERTY         |   can also link properties, same as :var x=(org-entry-get nil "MYPROPERTY")
//    +--------+--------------------+
//    | value                    [+]|   can expand src to fill pane
//    +-----------------------------+
//    | 1 | REBOL[]                 |   x and y are injected into code before running it, in this case: 
//    | 2 | print [ x "^/" y ]      |   x: "string"
//    | 3 | probe z                 |   y: "a string"
//    +---+----+--------------------+   z: {lol wut}
//    | preset | [▴][ filename ][▾] |   save/load code from file, can use EXPORT_FILE_NAME as an input
//    +--------+--------------------+
//
//
// node ui (process view)
//    +-----------------------------+
//    | node name                   |    grip here
//    +------------+----------------+
//   [| input name |                |    wire into this
//    +------------+--+-------------+
//    |               | output name |]   wire out of this
//    +---------------+-------------+
//
// node ui (relationship view)
//    +-----------------------------+
//   [| article name                |]   grip here, wire here
//    +-----------------------------+
//    | user exposed node param     |
//    +-----------------------------+


bool			doup;
article?[]		articles;	// article list
node?[] 		nodes;		// node list
port?[]		ports;		// var list

string loadmyorg (string f) {
	if (f != null) {
		if (f.strip() != "") {
			File orgfile = File.new_for_path(f);
			if (orgfile.query_exists() == true) {
				try {
					uint8[] c; string e;
					orgfile.load_contents (null, out c, out e);
					return (string) c;
				} catch (Error e) {
					print ("\tloadmyorg:\tfailed to read %s: %s\n", orgfile.get_path(), e.message);
				}
			} else { print("\tloadmyorg:\t%s doesn't exist, aborting...\n",f); }
		} else { print("\tloadmyorg:\t%s is empty, aborting...\n",f); }
	} else { print("\tloadmyorg:\tpath is null, aborting...\n"); }
	return "";
}

// step through the org file, 
// detect article header
//	search for end of article
//	capture article text
//	send article text to node parser
//		step through article
//		detect NAME
//			look for following NAME-able entitiy (src block, table, result, etc.)
//			if entity is found, searc for end of entity
//				send entity and NAME name to node builder
//					use NAME name as node name
//					determine entity type
//					break down headers into node properties accordingly
//					search for variable definition or use in the headers and entity body (val:var sytnax)
//						build ports using variables if they don't exist already
//						reserve the node for crosschecking if found
//					search for following RESULT and NAMED RESULT if entity is a source block
//						if NAMED RESULT is found make it a port:
//							port name = NAME preceeding RESULT, if NAME has no value assigned
//							port owner = ENTITY ID (preceeding src block)
//							port cargo = RESULT content
//                

void capturesrcblock (string b) {

}

void captureproperty (string p) {

}

void loadarticles (string f) {
	if (f != null) {
		if (f.strip() != "") {
			string[] markfortransit = {}; // check for linkage after all data is harvested
			string[] lines = f.split("\n");
			for (int i = 0; i < lines.length; i++) {
				if (lines[i].get_char(0) == '*' && lines[i].get_char(1) == ' ') {
					article aa = new article();
					aa.name = lines[i].replace("*","").strip();
					print("article name = %s\n",aa.name);
					aa.id = "%u".printf(aa.name.hash());
					print("article id = %s\n",aa.id);
					string[] articletext = {};
					for (int n = (i + 1); n < lines.length; n++) {
						if (lines[n].get_char(0) != '*') {
							articletext = articletext + lines[n];
							print("collecting article text: %s\n",lines[n]);
						} else { break; }
					}
					if (articletext.length != 0) {
						int sbc = 0;
						for (int b = 0; b < articletext.length; b++) {
							string ks = articletext[b].strip();
							int k = b + 1;
							if (ks.strip() == ":PROPERTIES:") {
								k = b + 1;
								while (articletext[k].strip().substring(0,5) != ":END:") {
									ks = articletext[k].strip();
									string[] ksp = ks.split(":");
									if (ksp.length > 2 && ksp[0].strip() == "") {
										node nn = new node();
										nn.name = "property_%s".printf(ksp[1].strip());
										nn.id = "%u".printf(nn.name.hash());
										nn.article = aa.id;
										nn.type = "property";
										nn.value = ksp[2].strip();
										// properties are treated as variables, so they get a port
										port pp = new port();
										pp.owner = nn.id;
										pp.name = ksp[1].strip();
										pp.id = "%u".printf(pp.name.hash());
										pp.cargo = ksp[2].strip();
										nn.ports = nn.ports + pp.id;
										ports = ports + pp;
										aa.nodes = aa.nodes + nn.id;
										nodes = nodes + nn;
										print("nodes.length = %d\n",nodes.length);
									}
									k += 1;
									if (k > 100) { break; } // suckshit if there's more than 100 lines in the propbin
								}
							}
							if (articletext[b].get_char(0) == '#') {
								if (articletext[b].substring(0,6) == "#+NAME") {
									
								}
								if (articletext[b].substring(0,5) == "#+BEG") {
									sbc += 1;
									node nn = new node();
									nn.name = "%s_srcblock%d".printf(aa.name,sbc);
									nn.id = "%u".printf(nn.name.hash());
									nn.article = aa.id;
									nn.type = "src block";
									string[] srcheader = articletext[b].split(":");
									print("src block header begin: %s\n", srcheader[0]);
									string[] blockdef = srcheader[0].split(" ");
									if (blockdef.length > 1) { nn.cmd = blockdef[1].strip().split(" "); }
									if (srcheader.length > 1) {
										for (int p = 1; p < srcheader.length; p++) {
											if (srcheader[p].substring(0,4) == "var ") {
												print("found a var: %s\n",srcheader[p]);
												srcheader[p] = srcheader[p].replace("var ","");
												string[] varparts = srcheader[p].split("=");
												if (varparts.length > 1) {
													for (int q = 0; q < (varparts.length - 1); q += 2) {
														port pp = new port();
														pp.owner = nn.id;
														pp.name = varparts[q].strip();
														pp.id = "%u".printf(pp.name.hash());
														pp.cargo = varparts[q+1].strip();
														if (pp.cargo.contains("org-entry-get")){
															print("\tport contains an org-entry-get, saving for crosscheck...\n");
															markfortransit = markfortransit + pp.id;
														} else {
															if (pp.cargo.contains(" ") == false) {
																if (pp.cargo.contains(".") == false) {
																	// single word, may be a var name
																	// reserve for link-checking
																	print("\tport cargo is a single work, saving for crosscheck...\n");
																	markfortransit = markfortransit + pp.id;
																}
															}
														}
														ports = ports + pp;
														nn.ports = nn.ports + pp.id;
													}
												}
											} else {
												narg gg = new narg();
												string[] argparts = srcheader[p].split("\"");
												if (argparts.length > 1) {
													gg.name = argparts[0].split(" ")[0].strip();
													gg.value = argparts[1].replace("\"","").strip();
												} else {
													argparts = srcheader[p].split(" ");
													if (argparts.length > 1) {
														gg.name = argparts[0].strip();
														gg.value = argparts[1].strip();
													}
												}
												nn.nargs = nn.nargs + gg;
											}
										}
									}
									k = b + 1;
									print("\tchecking node content: %s\n", articletext[k]);
									nn.value = "";
									while (articletext[k].substring(0,5) != "#+END") {
										nn.value = nn.value.concat(articletext[k], "\n");
										k += 1;
										if (k > 5000) { break; } // may need to raise this in special cases
									}
									nn.value = nn.value.strip();
									aa.nodes = aa.nodes + nn.id;
									print("aa node count: %d\n", aa.nodes.length);
									print("added node ref %s to %s\n", nn.id, aa.name);
									nodes = nodes + nn;
								}
							}
						}
					}
					articles = articles + aa;
				}
			}
			if (markfortransit.length > 0) {
				print("crosschecking...\n");
				foreach (string pid in markfortransit) {
					for (int t = 0; t < ports.length; t++) {
						if (ports[t].id == pid) { 
							print("\tchecking port %s\n",ports[t].name);
							string sample = ports[t].cargo.strip();
							if (sample.contains("org-entry-get")) {
								print("\t\tsample contains org-entry-get: %s\n", sample);
								string[] s = sample.split("\"");
								if (s.length > 1) { 
									sample = s[1].strip();
									print("\t\torg-entry-get varname is: %s\n", sample);
								}
							}
							foreach (port u in ports) {
								if (u.id != ports[t].id) {
									print("\tcomparing %s with %s\n", u.name, sample);
									if (u.name.strip() == sample) {
										ports[t].source = u.id;
										ports[t].org = ports[t].cargo;
										ports[t].cargo = u.cargo;
										print("\t\tset %s.cargo to: %s, from: %s\n",ports[t].name, ports[t].cargo, ports[t].org);
										break;
									}
								}
							}
							break;
						}
					}
				}
			}
		}
	}
}

int getarticleindex (string id) {
	for (int i = 0; i < articles.length; i++) {
		if (articles[i].id == id) { return i; }
	}
	return -1;
}

int getnodeindex (string id) {
	for (int i = 0; i < nodes.length; i++) {
		if (nodes[i].id == id) { return i; }
	}
	return -1;
}

int getportindex (string id) {
	for (int i = 0; i < ports.length; i++) {
		if (ports[i].id == id) { return i; }
	}
	return -1;
}

public class Outliner : Gtk.Box {
	private Gtk.DrawingArea img;
	Gtk.GestureDrag touchpan;
	Gtk.EventControllerScroll wheeler;
	Gtk.EventControllerMotion hover;
	private double[] 	moom;		// live mousemove xy
	private double[]	mdwn;		// live mousedown xy
	private double[]	olsz;		// pre-draw size xy
	private double[]	olof;		// pre-draw offset xy
	private double[]	olmd;		// pre-draw mousedown xy
	private double		olbh;		// post-draw bar height
	private double		posx;		// post-draw offset x
	private double		posy;		// post_draw offset y
	private double		sizx;		// post-draw size x
	private double		sizy;		// post-draw size y 
	private double		trgx;		// post-draw mousedown x
	private double		trgy;		// post-draw moudedown y
	private double 	barh;		// row height
	private int		artcl;	// selected article index
	private int		snod;		// selected node index
	private bool		dosel;		// do selection toggle
	private double[]	rssz;		// forecastlist pre-draw size memory for isolate
	private string		txtc;		// text color
	private string		rowc;		// row color
	private string		tltc;		// title color
	private bool		ipik;
	private bool		ipan;
	private bool		izom;
	private bool		iscr;
	private Gtk.CssProvider	boxcsp;
	private string				boxcss;
	public Outliner () { 
		print("outliner construction started...\n");
		img = new Gtk.DrawingArea();
		img.margin_top = 10;
		img.margin_bottom = 10;
		img.margin_start = 10;
		img.margin_end = 10;
		img.content_width = 780;
		img.content_height = 780;
		this.set_orientation(VERTICAL);
		this.spacing = 10;
		this.vexpand = true;
		this.hexpand = true;

		boxcsp = new Gtk.CssProvider();
		boxcss = ".xx { background: #FF0000FF; }";
		boxcsp.load_from_data(boxcss.data);
		this.get_style_context().add_provider(boxcsp, Gtk.STYLE_PROVIDER_PRIORITY_USER);	
		this.get_style_context().add_class("xx");

		dosel = false;
		artcl = 999999;

		moom = {0.0,0.0};
		mdwn = {0.0,0.0};
		olsz = {300.0,300.0};
		olof = {0.0,0.0};
		olmd = {0.0,0.0};
		olbh = 30.0;
		posx = 0.0;
		posy = 0.0;
		sizx = 0.0;
		sizy = 0.0;
		trgx = 0.0;
		trgy = 0.0;
		barh = 30.0;
		rssz = {300.0,300.0};

		txtc = "#55BDFF";
		rowc = "#1A3B4F";
		tltc = "#112633";

		izom = false;	// zoom mode
		ipan = false;	// pan mode
		iscr = false;	// scroll mode
		ipik = false;	// pick mode
		print("adding outliner draw function...\n");
		img.set_draw_func((da,ctx,daw,dah) => {
			print("img.draw\tdrawing %d articles...\n",articles.length);
			print("img.draw\tdrawing area is %d x %d\n",daw,dah);
			if (articles.length > 0) {
				var bc = Gdk.RGBA();
				var presel = artcl;
// graph coords
				sizx = olsz[0];
				sizy = olsz[1];
// zoom
				if (izom) {
					sizx = (olsz[0] + (moom[0] * 2.0));
					sizy = (olsz[1] + (moom[1] * 2.0));
				}
				posy = olof[1];
				posx = olof[0];
				if (izom) {
					posx = olof[0] + ( (mdwn[0] - olof[0]) - ( (mdwn[0] - olof[0]) * (sizx / olsz[0]) ) ) ;
					posy = olof[1] + ( (mdwn[1] - olof[1]) - ( (mdwn[1] - olof[1]) * (sizy / olsz[1]) ) ) ;
					trgx = olmd[0] + ( (mdwn[0] - olmd[0]) - ( (mdwn[0] - olmd[0]) * (sizx / olsz[0]) ) ) ;
					trgy = olmd[1] + ( (mdwn[1] - olmd[1]) - ( (mdwn[1] - olmd[1]) * (sizy / olsz[1]) ) ) ;
				}
// pan, scroll
				if(ipan || iscr) {
					posx = olof[0] + moom[0];
					posy = olof[1] + moom[1];
					trgx = olmd[0] + moom[0];
					trgy = olmd[1] + moom[1];
				}
// pick
				if (ipik) {
					trgx = mdwn[0];
					trgy = mdwn[1];
				}
// bar height
				barh = sizy / articles.length;
				ctx.select_font_face("Monospace",Cairo.FontSlant.NORMAL,Cairo.FontWeight.BOLD);
				ctx.set_font_size(barh * 0.8); 
				Cairo.TextExtents extents;
				ctx.text_extents (articles[0].name, out extents);
				var xx = extents.width + 40.0;
// clamp pos y
				posy = double.min(double.max(posy, (0 - ((barh * articles.length)-dah))), 0.0);
				posx = double.min(double.max(posx, (daw - xx)), 0.0);
// paint bg
				bc.parse(rowc);
				ctx.set_source_rgba(bc.red,bc.green,bc.blue,1);
				ctx.paint();
// check selection hit
				var px = 0.0;
				var py = 0.0;
				if (ipik && mdwn[0] > 0 && izom == false && ipan == false && iscr == false) {
					artcl = 999999;
					for (int i = 0; i < articles.length; i++) {
						px = 0.0;
						py = 0.0;
						px = px + posx;
						py = i * barh;
						py = py + posy;
						if (mdwn[1] > py && mdwn[1] < (py + (barh - 1))) {
							artcl = i;
							print("selected article is: %s\n",articles[i].name);
							trgx = mdwn[0]; trgy = mdwn[1];
							break;
						}
					}
				}
// draw rows
				for (int i = 0; i < articles.length; i++) {
					px = 0.0;
					py = 0.0;
					px += posx;
					py = i * barh;
					py = py + posy;
					string xinf = articles[i].name;
// draw selection highlight
					if (i == artcl) { 
// TODO: insert article color here
						bc.parse(txtc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 0.1));
						ctx.rectangle(0.0, py, daw, (barh - 1));
						ctx.fill ();
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10.0), (py + (barh * 0.75)));
						ctx.show_text(xinf);
// draw unselected
					} else {
						bc.parse(txtc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.rectangle(0.0, py, daw, (barh - 1));
						ctx.fill();
						bc.parse(rowc);
						ctx.set_source_rgba(bc.red,bc.green,bc.blue,((float) 1.0));
						ctx.move_to((px + 10), (py + (barh * 0.75)));
						ctx.show_text(xinf);
					}
				}
// do selection ?
				if (artcl >= 0 && artcl != presel) {
					dosel = true;
				}
// reset mouseown if not doing anythting with it

				if (izom == false && ipan == false && iscr == false) {
					mdwn[0] = 0;
					mdwn[1] = 0;
					ipik = false;
				}
				if (iscr) {
					iscr = false;
					olsz = {sizx, sizy};
					olof = {posx, posy};
					olmd = {trgx, trgy};
				}
			}
		});
		print("adding outliner gesture events...\n");
		touchpan = new Gtk.GestureDrag();
		wheeler = new Gtk.EventControllerScroll(VERTICAL);
		hover = new Gtk.EventControllerMotion();
		img.add_controller(touchpan);
		img.add_controller(wheeler);
		img.add_controller(hover);
		touchpan.drag_begin.connect ((event, x, y) => {
			if (drwm == 1) { 
				print("current button is: %u\n", event.get_current_button());
				ipik = (event.get_current_button() == 1);
				izom = (event.get_current_button() == 3);
				ipan = (event.get_current_button() == 2);
				mdwn = {x, y};
				if (ipik) { 
					olmd = {mdwn[0], mdwn[1]};
					trgx = mdwn[0]; 
					trgy = mdwn[1]; 
					img.queue_draw(); 
				}
			}
		});
		touchpan.drag_update.connect((x, y) => {
			print("draw mode is: %d\n", drwm);
			if (drwm == 1) { 
				if (izom == false && ipan == false && ipik == false) { mdwn = {x, y}; }
				moom = {x, y};
				if (izom || ipan) { img.queue_draw(); print("draging\n"); }
			}
		});
		touchpan.drag_end.connect(() => {
			ipan = false;
			izom = false;
			iscr = false;
			if (drwm == 1) { 
				if (ipik) { img.queue_draw(); }
				olsz = {sizx, sizy};
				olof = {posx, posy};
				olmd = {trgx, trgy};
				olbh = barh;
			}
			if (dosel) { print("dosel: selected article is: %s\n", articles[artcl].name); dosel = false; }
		});
		hover.motion.connect ((event, x, y) => {
			if (drwm == 1) {
				if (izom == false && ipan == false && ipik == false) { mdwn = {x, y}; }
			}
		});
		wheeler.scroll.connect ((x,y) => {
			print("scrollin...\n");
			if (drwm == 1) {
				iscr = true;
				moom = {0.0, (-y * 20.0)};
				img.queue_draw();
			}
			return true;
		});
		this.append(img);
	}
}

int main (string[] args) {
	Gtk.Application wut = new Gtk.Application ("com.test.test", GLib.ApplicationFlags.FLAGS_NONE);
	wut.activate.connect(() => {
		Gtk.ApplicationWindow win = new Gtk.ApplicationWindow(wut);
		win.default_width = 800;
		win.default_height = 800;
		drwm = 1;

/*
		string src = "";

		Gtk.Box 				scrollbox 			= new Gtk.Box(VERTICAL,10);
		Gtk.ScrolledWindow 	srcscroll 			= new Gtk.ScrolledWindow();
		Gtk.TextTagTable 		srctextbufftags 	= new Gtk.TextTagTable();
		GtkSource.Buffer		srctextbuff 		= new GtkSource.Buffer(srctextbufftags);
		GtkSource.View			srctext 			= new GtkSource.View.with_buffer(srctextbuff);

		srcscroll.height_request = 200;
		srctext.accepts_tab = true;
		srctext.set_monospace(true);

		srctextbuff.set_highlight_syntax(true);
		srctextbuff.set_style_scheme(GtkSource.StyleSchemeManager.get_default().get_scheme("Adwaita-dark"));
		srctext.buffer.changed.connect(() => {
			if (doup) {
				doup = false;
				src = srctext.buffer.text;
				srcscroll.height_request = int.min(500,int.max(200,((int) (srctext.buffer.get_line_count() * 11) + 60)));
				doup = true;
			}
		});	

		srctext.tab_width 						= 4;
		srctext.indent_on_tab 					= true;
		srctext.indent_width 					= 4;
		srctext.show_line_numbers 				= true;
		srctext.highlight_current_line 		= true;
		srctext.vexpand 						= true;
		srctext.top_margin 					= 10;
		srctext.left_margin 					= 10;
		srctext.right_margin 					= 10;
		srctext.bottom_margin 					= 10;
		srctext.space_drawer.enable_matrix 	= true;
		srctext.opacity = 0.8;
		scrollbox.vexpand 						= true;
		scrollbox.margin_top 					= 0;
		scrollbox.margin_end 					= 0;
		scrollbox.margin_start 				= 0;
		scrollbox.margin_bottom 				= 0;
*/



		//srcscroll.set_child(srctext);
		//scrollbox.append(srcscroll);
		//win.set_child(scrollbox);

		Outliner oimg = new Outliner();
		string org = loadmyorg("./testme.org");
		loadarticles(org);
		print("article count: %d\n",articles.length);
		print("node count   : %d\n",nodes.length);
		win.set_child(oimg);
		//oimg.img.queue_draw();
		win.present();
	});
	return wut.run (args);
}
