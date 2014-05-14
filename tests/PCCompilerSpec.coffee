###
PseuCo Compiler  
Copyright (C) 2013  
Saarland University (www.uni-saarland.de)  
Sebastian Biewer (biewer@splodge.com)

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
###


programs = 
	"println":
		"""
		// #1
		mainAgent {
			println("Hello World!");
		}
		"""

	"variables":
		"""
		// #2
		int x = 5;
		int y = x + 2;
		bool b = x < y;
		int z = x + (b) ? y : -1;

		mainAgent {
			int a = z;
			if (a + 1 == z + 1) {
				z = x*x;
			}
			println("The result is ", z);
		}
		"""
	"Listing 6.1":
		"""
		// #3: 6.1
		mainAgent {
			int j , n ;
			n = 1;
			for ( j = 1; j <= 5 ; j++){
				n = n*j;
			}
			// Hier ist die Arbeit erledigt .
			println ( " Die Fakultaet von 5 ist :  " + n ); // Ich verrate was rauskommt .
		}
		"""
	"Listing 6.2":
		"""
		// #4: 6.2
		void countDutch (){
			println ( "Een " );
			println ( "Twee " );
			println ( "Drie " );
		}
		void countFrench (){
			println ( " Un " );
			println ( " Deux " );
			println ( " Trois " );
		}
		mainAgent {
			agent a1 = start countDutch (); // Ich lass einen Agenten los !
			agent a2 = start countFrench (); // Und noch einen !
			println ( " Beide  zaehlen ! " ); // Das sollen alle wissen .
		}

		"""
	"Listing 6.3":
		"""
		// #5: 6.3
		void factorial ( int z ){
			int j , n ;
			n=1;
			for ( j =1; j <= z ; j ++){
				n= n*j;
			}
			println ( " Die Fakultaet von " + z + " ist " + n + " . " ); // Ich verrate was rauskommt
		}
		mainAgent {
			agent a1 = start factorial (3);
			agent a2 = start factorial (5);
		}

		"""
	"Listing 7.1":
		"""
		// #6: 7.1
		int mid , fin ;
		intchan cc ;
		void factorial ( int z , intchan c ){
			int j , n ;
			n = 1;
			for ( j =1; j <= z ; j ++){
				n= n*j;
			}
			// Hier ist die Arbeit erledigt .
			c <! n ; // Ich sende , was rauskommt .
		}
		mainAgent {
			agent a1 = start factorial (3 , cc );
			// Ich lasse
			println ( " Der  erste  Agent  arbeitet  fuer  mich . " );
			mid = <? cc ;
			// Mal sehen was der ausrechnet .
			agent a2 = start factorial ( mid , cc );
			// Und noch einen .
			println ( " Der  zweite  Agent  arbeitet  fuer  mich . " );
			fin = <? cc ;
			// Mal sehen was der draus macht .
			println ( " Die  Fakultaet  von  der  Fakultaet  von  3  ist  " + fin + " . " );
		}

		"""
	"Listing 7.2":
		"""
		// #7: 7.2
		int mid , fin ;
		intchan dd ;
		intchan cc ;
		void factorial ( intchan c ){
			int j , n =1 ;
			int z = <? dd ; // Womit soll ich rechnen ?
			for ( j =1; j <= z ; j ++){
				n= n*j;
			}
			// Hier ist die Arbeit erledigt .
			c <! n ; // Ich sende , was rauskommt .
		}
		mainAgent {
			agent a1 = start factorial ( cc );
			// Ich erzeugen einen Agenten .
			agent a2 = start factorial ( cc );
			// Und der andere auch .
			dd <! 3;
			// Werfen wir mal was zu rechnen aus .
			mid = <? cc ;
			// Mal sehen was einer ausrechnet .
			dd <! mid ;
			// Das reichen ich weiter .
			fin = <? cc ;
			// Mal sehen , was der andere draus macht .
			println ( " Die  Fakultaet  von  der  Fakultaet  von  3  ist  " + fin + " . " );
		}

		"""
	"Listing 7.3":
		"""
		// #8: 7.3
		int fin ;
		intchan cc ;
		void factorial ( intchan c ){
			int n =1;
			int z = <? c ; // Womit soll ich rechnen ?
			for ( int j =1; j <= z ; j ++){
				n= n*j;
			}
			// Hier ist die Arbeit erledigt .
			c <! n ; // Ich sende , was rauskommt .
		}
		mainAgent {
			agent a1 = start factorial ( cc );
			// Ich lasse einen Agenten loslegen .
			agent a2 = start factorial ( cc );
			// Und noch einen .
			cc <! 3;
			fin = <? cc ;
			// Mal sehen was der draus macht .
			println ( " Die  Fakultaet  von  der  Fakultaet  von  3  ist  " + fin + " . " );
		}

		"""
	"Listing 7.4":
		"""
		// #9: 7.4
		intchan10 cc ;
		intchan10 dd ;
		void factorial ( intchan d , intchan c ){
			int j , n , z ;
			while ( true ) { // Wie waers mit ewigem Leben ?
			z = <? d ;
			// Womit soll ich rechnen ?
			n =1;
			for ( j =1; j <= z ; j ++){
				n= n*j;
			}
			c <! n ; // Ich sende , was rauskommt .
		}
		// Und fange wieder von vorne an .
		}
		mainAgent {
			int j ;
			agent[4] a = {
				start factorial ( dd , cc ),
				start factorial ( dd , cc ),
				start factorial ( dd , cc ),
				start factorial ( dd , cc )
			};
			// Ich lasse ein paar Agenten loslege
			}
			for ( j =1; j <=8 ; j ++){
				dd <! j ;
				// Hier gibt ’s Arbeit .
			}
			// Jetzt ham alle viel zu tun .
			for ( j =1; j <=8 ; j ++){
				int res = <? cc ;
				// Hier sammel ich die Ergebnisse
				println ( " Die  Fakultaet  von " + j + "  ist  " + res + " . " );
			}
		}

		"""
	"Listing 7.5":
		"""
		
		intchan10 cc ;
		intchan10 dd ;
		boolchan ff ;
		void factorial ( boolchan f , intchan d , intchan c )
		{
			int j ,n , z ;
			bool run = true ;
			while ( run ) { // Ewiges Leben ?
				select {
					case <? f :{ // Aha , Zeit aufzuhoeren .
						run = false ;
					}
					case z = <? d :{ // Aha , Weitermachen .
						n =0;
						for ( j =1; j <= z ; j ++){
							n= n*j;
						}
						c <! n ; // Ich sende , was rauskommt .
					}
				} // Und fange wieder von vorne an .
			}
			println ( " Kein  ewiges  Leben " );
		}
		mainAgent {
			int j ;
			agent[4] a = {
				start factorial ( dd , cc ),
				start factorial ( dd , cc ),
				start factorial ( dd , cc ),
				start factorial ( dd , cc )
			};
			for ( j =1; j <=8 ; j ++){
				dd <! j ;
				// Hier gibt ’s Arbeit .
			}
			// Jetzt ham alle viel zu tun .
			for ( j =1; j <=8 ; j ++){
				int res = <? cc ;
				// Hier sammel ich die Ergebnisse ein
				println ( " Eine  der  Fakultaeten  von  1  bis  8  ist  " + res + " . " ); // Ui .
			}
			for ( j =0; j <4 ; j ++){
				ff <! true ;
				// Jetzt ist Schluss fuer euch .
			}
		}

		"""
	"Listing 7.6":
		"""
		intchan [8] result ;
		void factorial ( int z , intchan res ){
			int j , n ;
			n = 1;
			for ( j =1; j <= z ; j ++){
				n = n*j;
			}
			res <! n ; // Ich terminiere , nachdem ich zurueck sende , was rauskommt .
		}
		mainAgent {
			int j ;
			for ( j =0; j <8 ; j ++){
				start factorial ( j +1 , result [ j ]); // Ich lasse ein paar ( namenlose ) Agente
			}
			//
			// Vielleicht hier noch eben eine nagelneue Primzahl berechnen .
			// Oder sonst irgendetwas erledigen .
			//
			for ( j =0; j <8 ; j ++){
			// Hier frage ich die hoffentlich fertigen Ergebni
				println ( " Die  Fakultaet  von " + ( j +1) + "  ist  " + ( <? result [ j ]) + " . " );
			}
		}

		"""
	"Listing 7.7":
		"""
		intchan100 [5] conn ;
		void prime ( int v , intchan in , intchan out ){
			int p ;
			while ( true ) {
				p = <? in ;
				if ( p % v != 0 || p == v ) { out <! p; }
			}
		}
		mainAgent {
			start prime (7 ,conn [0] ,conn [1]);
			start prime (5 ,conn [1] ,conn [2]);
			start prime (3 ,conn [2] ,conn [3]);
			start prime (2 ,conn [3] ,conn [4]);
			for ( int j =2; j <=100 ; j ++){
				conn [0] <! j ;
			}
			while ( true ) { // Alles , was aus conn [4] raus kommt , ist prim .
				println ( ( <? conn [4]) + " ist  eine  Primzahl . " );
			}
		}

		"""
	"Listing 7.8":
		"""
		intchan100 buff ;
		void produce ( intchan out , string id ){
			while ( true ) {
				int p = 3; // Produziere etwas.
				println ( " Erzeuger  " + id + "  hat  " + p + "  produziert . " );
				out <! p;
				}
			}
		void consume ( intchan in , string id ){
			while ( true ) {
				int c = <? in;
				println ( "  Verbraucher  " + id + "  hat  " + c + "  konsumiert . " );
			}
		}
		mainAgent {
			start produce ( buff , " 1 "); // Ein Erzeuger .
			start  produce ( buff , " 2 " ); // Zwei Erzeuger .
			start  produce ( buff , " 3 "  );// Drei Erzeuger .
			start  consume ( buff ,"A");
			start  consume ( buff ,"B");
			start  consume ( buff ,"C");
			start  consume ( buff ,"D");
		}

		"""
	"Listing 7.9":
		"""
		intchan100 t12 ;
		intchan100 t23 ;
		boolchan100 k31 ;
		void assemblyB1 ( intchan in , intchan out , boolchan kan ) {

			int j ;
			int f ( int x ){ return x; }
			while (true) {
				<? kan;
				j = <? in;
				j = f(j);
				out <! j;
			}
		}
		void assemblyB2 ( intchan in , intchan out)
		{
			int j ;
			int g ( int x ){ return x;} //
			while (true) {
				j = <? in;
				j = g(j);
				out <! j;
			}
		}
		void assemblyB3 ( intchan in , intchan out , boolchan kan )
		{
			int j ;
			int h ( int x ){ return x; } //
			while (true) {
				j = <? in;
				j = h(j);
				kan <! true;
				out <! j;
			}
		}
		mainAgent{
			intchan100 in, out;

			for (int j =0; j <5 ; j ++){
				k31 <! true;
			}
			start assemblyB1 ( in , t12 , k31 );
			start assemblyB2 ( t12 , t23 );
			start assemblyB3 ( t23 , out , k31 );
			in <! 17;
		}

		"""
	"Listing 7.10":
		"""
		//intchan100000 w ;
		intchan100 w;
		mainAgent {
			int curr ;
			int [10] nxt ;
			bool found = false ;
			w <! 0;
			// Hier der initiale Knoten , den puffere ich in mei
			while (!( found )){
				curr = <? w ;
				// Noch ein Knoten zu bearbeiten .
				found = ( curr == 13); // Vielleicht ists ja der gesuchte Knoten .
				println ( " Ich  bearbeite  Knoten  " + curr );
				if (! alreadySeen ( curr )){ // Kenn ich noch nicht .
					remember ( curr );
					nxt = next ( curr );
					// Und der hat Nachfolger .
					for ( int j =0 ; j < 10; j ++){
						w <! nxt [ j ];
						// Die Nachfolger puffere in meinem Kanal ich .
					}
				}
			}
			println ( " Ja ,  der  Knoten  ist  erreichbar . " );
		}

		bool alreadySeen(int c) {
			return true;
		}

		void remember(int c) {}

		int[10] next(int c) {
			int[10] result = {1,2,3,4,5,6,7,8,9,10};
			return result;
		}

		"""
	"Listing 7.11":
		"""
		//intchan100000 [4] w ;
		intchan100 [4] w ;
		boolchan res ;
		agent [4] a ;
		void search ( int id , boolchan r ) {
			int curr ;
			int [10] nxt ;
			bool found = false ;
				while (!( found )){
				curr = <? w [ id ];
				found = ( curr == 13);
				println ( " Agent " + id + " bearbeitet  Knoten  " + curr );
				if (! alreadySeen ( curr )){
					remember ( curr );
					nxt = next ( curr );
					for ( int j =0 ; j < 10; j ++){
						int v = nxt [j];
						w [ v % 4] <! v ;
					}
					}
			}
			r <! true ;
		}
		mainAgent {
			for ( int j =0; j <4 ; j ++){
				a [ j ] = start search (j , res ); // Ich lasse vier Agenten loslegen .
			}
			w [0] <! 0; // Einer bekommt den initialen Knoten
			<? res ; // Sagt mir jemand Bescheid ?
			println ( " Ja ,  der  Knoten  ist  erreichbar . " );
		}

		bool alreadySeen(int c) {
			return true;
		}

		void remember(int c) {}

		int[10] next(int c) {
			int[10] result = {1,2,3,4,5,6,7,8,9,10};
			return result;
		}

		"""
	"Listing 8.1":
		"""
		int n ;
		void zaehler (){
			int loop ;
			for ( loop = 0; loop < 5; loop ++){
				n = n - 1;
			}
		}
		mainAgent {
			while(true){n = 10;
			agent a1 ;
			agent a2 ;
			a1 = start zaehler ();
			a2 = start zaehler ();
			join a1 ;
			join a2 ;
			println ( " Der  Wert  ist  " + n );}
		}

		"""
	"Listing 8.3":
		"""
		int n ;
		mutex guard_n ;
		// Sicherer Raum
		void zaehler (){
			int loop ;
			for ( loop = 0; loop < 5; loop ++){
				lock guard_n;
				n = n - 1;
				unlock guard_n;
			}
		}
		// Sicheren Raum betreten
		// Sicheren Raum verlassen
		mainAgent {
			n = 10;
			agent a1 ;
			agent a2 ;
			a1 = start zaehler ();
			a2 = start zaehler ();
			join a1 ;
			join a2 ;
			println ( " Der  Wert  ist  " + n );
		}

		"""
	"Listing 8.5":
		"""
		mutex guard_n;
		int n = 0;

		void zaehlerMitLock (){
			for ( int loop = 0; loop < 10; loop ++){
				lock guard_n; // woher kommt dieser guard?
				n = n + 1;
				unlock guard_n;
				// Sicheren Raum betreten
				// Sicheren Raum verlassen
			}
		}
			void zaehlerOhneLock (){
				for ( int loop = 0; loop < 10; loop ++){
				n = n + 1;
			}
		}

		"""
	"Listing 8.6":
		"""
		int n ;
		mutex guard_n ;
		// Sicherer Raum
		void zaehler (){
			int loop ;
			for ( loop = 0; loop < 5; loop ++){
				lock guard_n;
				int temp = n ;
				unlock guard_n;
				temp = temp - 1;
				lock guard_n;
				n = temp ;
				unlock guard_n;
			}
		}
		mainAgent {
			n = 0;
			agent a1 ;
			agent a2 ;
			a1 = start zaehler ();
			a2 = start zaehler ();
			join a1 ;
			join a2 ;
			println ( " Der  Wert  ist  " + n );
		}

		"""
	"Listing 8.7":
		"""
		int n ;
		mutex guard_n ;
		// Sicherer Raum
		void zaehler (){
			int loop ;
			lock guard_n;
			for (loop = 0; loop < 5; loop++){
				n = n - 1;
			}
			unlock guard_n;
		}
		// Sicheren Raum betreten
		// Sicheren Raum verlassen
		mainAgent {
			n = 10;
			agent a1 ;
			agent a2 ;
			a1 = start zaehler ();
			a2 = start zaehler ();
			join a1 ;
			join a2 ;
			println ( "Der Wert ist" + n );
		}

		"""
	"Listing 8.8":
		"""
		monitor AtomareGanzeZahl {
			mutex guard ; // nicht direkt zugreifbar
			int n ;
	
			// nicht direkt zugreifbar , dies ist das gemeinsame Datum
			void set ( int x ){
				lock guard;
				n = x;
				unlock guard;
			}
			int get (){
				lock guard;
				int temp = n ;
				unlock guard;
				return temp ; // TODO : Wie wird das in der JVM geloest , erst das unlock , dann d
			}
			void increment (){
				lock guard;
				n = n + 1;
				unlock guard;
			}
			void decrement (){
				lock guard;
				n = n - 1;
				unlock guard;
			}
			bool compareAndSet ( int expected , int v ){
				lock guard;
				bool res = false ;
				if (n == expected) {
					n = v;
					res = true ;
				}
				unlock guard;
				return res ;
			}
		}

		"""
	"Listing 8.9":
		"""
		monitor AtomareGanzeZahl {
			mutex guard ; // nicht direkt zugreifbar
			int n ;
	
			// nicht direkt zugreifbar , dies ist das gemeinsame Datum
			void set ( int x ){
				lock guard;
				n = x;
				unlock guard;
			}
			int get (){
				lock guard;
				int temp = n ;
				unlock guard;
				return temp ; // TODO : Wie wird das in der JVM geloest , erst das unlock , dann d
			}
			void increment (){
				lock guard;
				n = n + 1;
				unlock guard;
			}
			void decrement (){
				lock guard;
				n = n - 1;
				unlock guard;
			}
			bool compareAndSet ( int expected , int v ){
				lock guard;
				bool res = false ;
				if (n == expected) {
					n = v;
					res = true ;
				}
				unlock guard;
				return res ;
			}
		}


		AtomareGanzeZahl shared ; // Ein Monitor

		void zaehler (){
			for ( int loop = 0; loop < 5; loop ++){
				shared.decrement (); // Hier wird eine Monitor - Operation verwendet .
			}
		}
		mainAgent {
			shared.set (10); // Hier ist noch eine Monitor - Operation .
			agent a1 ;
			agent a2 ;
			a1 = start zaehler ();
			a2 = start zaehler ();
			join a1 ;
			join a2 ;
			println (" Der  Wert  ist  " + shared . get ()); // Hier die dritte Monitor - Operation .
		}
		"""
	"Listing 8.10":
		"""
		monitor Kanal20 {
			mutex guard ; // nicht direkt zugreifbar
			int[20] n; // nicht direkt zugreifbar , dies ist die gemeinsame Ressource
			int used = 0; // nicht direkt zugreifbar , zaehlt die belegten Kanalplaetze
			void put ( int x ){
				lock guard;
				if ( used < 20) {
					n [ used ] = x ;
					used ++;
				}
				unlock guard;
			}
			// Wir haben Platz , her damit
			int get (){
				lock guard;
				int temp ;
				if ( used > 0) {
					temp = n [0];
					for ( int j =1; j < used ; j ++)
						n [j -1]= n [ j ];
				}
				used --;
				unlock guard;
				return temp ;
			}
		}

		"""
	"Listing 8.11":
		"""
		monitor Kanal20 {
			mutex guard ; // nicht direkt zugreifbar
			condition platzIstFrei with true ; // nicht direkt zugreifbar , entspricht der Bedingung "
			condition datumIstDa with true;
			// nicht direkt zugreifbar , entspricht der Bedingung "
			int[20] n; // nicht direkt zugreifbar , dies ist die gemeinsame Ressource
			int used = 0; // nicht direkt zugreifbar , zaehlt die belegten Kanalplaetze
			void put ( int x ){
				lock guard;
				if (!(used < 20)) {
					unlock guard;
					waitForCondition platzIstFrei;
					lock guard;
				}
				n [ used ] = x ;
				used ++;
				signal datumIstDa;
				unlock guard;
			}
			int get (){
				lock guard;
				int temp ;
				if (!(used > 0)) {
					// Kein Datum fuer mich , schade .
					unlock guard;
					// Also Lock zurueckgeben .
					waitForCondition datumIstDa;
					// Entspannt warten , bis Datum da .
					lock guard;
					// Und wieder her mit dem Lock .
				}
				// Jetzt sollte ein Datum da sein .
				temp = n [0];
				for ( int j =1; j < used ; j ++){
					n [j -1]= n [ j ];
				}
				used --;
				signal platzIstFrei;
				// Uebrigens , jetzt ist ein Plaetzchen frei .
				unlock guard;
				return temp ;
			}
		}

		"""
	"Listing 8.12":
		"""
		monitor Kanal20 {
			mutex guard; // nicht direkt zugreifbar
			condition platzIstFrei with true; // nicht direkt zugreifbar, entspricht der Bedingung 
			condition datumIstDa with true; // nicht direkt zugreifbar, entspricht der Bedingung "
			int[20] n; // nicht direkt zugreifbar, dies ist die gemeinsame Ressource
			int used=0; // nicht direkt

			void put(int x) { 
				lock guard;
				while (!(used <20)) {
					waitForCondition platzIstFrei; 
				}		
				n[used] = x;
				used++; 
				signal datumIstDa; 
				unlock guard;
			}

			int get(){ 
				lock guard;
				int temp;
				while (!( used > 0)){
					waitForCondition datumIstDa; 
				}
				temp = n[0];
				for (int j=1; j < used; j++){
					n[j-1]=n[j]; 
				}
				used--;
				signal platzIstFrei; // Uebrigens, jetzt ist ein Plaetzchen frei. 
				unlock guard;
				return temp;
			}
		}
		"""
	"Listing 8.13":
		"""
		monitor PrimOderNicht {
			mutex guard; 
			condition istPrim with true; 
			int n;
			bool prim;

			void set(int x){
				lock guard;
				n = x;
				prim = prime(n); // Ein beliebiger Primzahltest 
				if (prim){
					signal istPrim; 
				}
				unlock guard; 
			}
	
			bool prime(int x) {
				// TODO Implement Primzahltest
				return true;
			}

			int get (){ 
				lock guard; 
				int temp = n; 
				unlock guard; 
				return temp;
			}
	
			int getPrime (){ 
				lock guard; 
				while (! prim ){
					lock guard; 
					waitForCondition istPrim; 
					unlock guard;
				}
				int temp = n; 
				signal istPrim; 
				unlock guard; 
				return temp;
			}
		}
		"""
	"Listing 8.14":
		"""
		monitor PrimOderNicht {
			mutex guard; // nicht direkt zugreifbar
			bool prim;
			condition istPrim with prim; // nicht direkt zugreifbar
			int n; 
	
			void set(int x){
				n = x;
				prim = prime(n); // Ein beliebiger Primzahltest 
				if (prim){
					signalAll istPrim; 
				}
			}
	
			bool prime(int x) {
				// TODO Implement Primzahltest
				return true;
			}
	
			int get (){ 
				return n;
			}
	
			int getPrime (){ 
				waitForCondition istPrim;
				return n;
			}
		}
		"""
	"Listing 8.15":
		"""
		monitor Semaphore { 
			int value;
			mutex guard;
			condition valueNonZero with value != 0;

			void init(int v) { 
				value = v;
			}
	
			void up() { 
				value++; 
				signalAll valueNonZero; 
			}
	
			void down () { 
				waitForCondition valueNonZero;
				value--; 
			}
		}
		"""


PC = require("PseuCo")
PCC = require("CCSCompiler")


describe "PseuCo parser", ->
	
	testProgram = (i) ->				 # "it" must be wrapped in a function
		it "should parse and compile \"#{i}\"", ->
			tree = null
			try
				tree = PC.parser.parse(programs[i])
			catch e
				e2 = new Error("Line #{e.line}, column #{e.column}: #{e.message}")
				e2.name = e.name
				throw e2
			expect(tree instanceof PC.Node).toBe(true)
			compiler = new PCC.Compiler(tree)
			ccs = compiler.compileProgram()
			

	for i of programs
		testProgram(i)
	null
	
	
	
	