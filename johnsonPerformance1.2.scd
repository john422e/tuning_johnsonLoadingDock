(
o = Server.default.options;
o.numWireBufs_(1024);
s.boot;
)
s.quit;
////////////////// USE THIS //////////////////////////////////////////////////////
(
var instrument = "CELLO";//"VIOLIN"; // "CELLO"
var title = "Johnson Museum Score" + instrument;
// constants for VISUAL
var cwd, textPath, instPath; //vlnPath, vcPath; //, vlnFreqFile, vlnFreqs;
var notesDepth1, notesDepth2, notesDepth3, notesDepth4; // stores available harmonic groups at each depth for notation
var depth1Data, depth2Data, depth3Data; // freqs and amps for synths
var peakDepths = [8, 64, 512];
var degrees=[0, 45, 90, 135, 180, 225, 270, 315];
var degreeLabels=['0°/360°', '45°', '90°', '135°', '180°', '225°', '270°', '315°']; // strings for window views
var labels; // will store window objects themselves
var wWidth=1540, wHeight=820, vWidth=(wWidth-40)/3, views;
var padding=30, stringHeight=700, stringGap=100, stringPad=100;
var a440=440, instStrings, instStringsRange, frets;
var rgbs=[
	[128, 170, 220], // cornflower blue
	[226, 234, 247], // pale blue
	[183, 213, 241], // light blue
	[232, 154, 51], // mustard yellow
	[241, 237, 224], // cream
	[208, 145, 134], // dusty rose
	[168, 119, 120], // mauve - red pink purple
	[233, 179, 152], // peach
];
var setViewsColors; // drawing function for recoloring background views
var cards; // for storing background colors
var dots=Array.fill(8, {0}); // for storing dot colors (finger placement)
// mutables that will get updated through routine
var depths=Array.fill(8, {0}); // for storing depth at each degree (0-3)
var facing=0, position_i, positions;
// constants for AUDIO
var audioPath, audioFileNames, bufs, bufPlayers, synth1, synth2, synth3;
var pans; // for dev only
var rampTime=0.1; // attack and release for all envs
// HID STUFF ------------------------------------------
var leftKey=123, rightKey=124, xKey=7, oKey=31, pedalLeft=126, pedalRight=125;

// FILE HANDLING ----------------------------------------------------------------------------------
// read in csv file with instrument freqs for notation, WILL NEED TO EXPAND FOR DEPTHS
cwd = PathName.new(thisProcess.nowExecutingPath).parentPath;
/*
textPath = cwd ++ "vlnFreqs.csv"; // TEMP
vlnFreqFile = CSVFileReader.read(textPath);
vlnFreqs = vlnFreqFile.collect(_.collect(_.interpret)); // converts into numbers
vlnFreqs.postln; // 2d array
*/

textPath = cwd ++ "analyses/string_chords/";
if( instrument == "VIOLIN", { instPath = textPath ++ "vln/" }, { instPath = textPath ++ "vc/" });

// build arrays for each instrument for each depth
notesDepth4 = Array.fill(8, { Array.new(3) }); // empty array to add groups from each depth

notesDepth1 =  Array.fill( 8, {
	arg i;
	var fn, subdirectory=instPath ++ peakDepths[0] ++ '/', groups, choice;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	groups = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	choice = groups.choose; // select random group from this depth
	notesDepth4[i].add(choice); // add choice
	choice;
});

notesDepth2 =  Array.fill( 8, {
	arg i;
	var fn, subdirectory=instPath ++ peakDepths[1] ++ '/', groups, choice;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	groups = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	choice = groups.choose; // select random group from this depth
	notesDepth4[i].add(choice); // add choice
	choice;
});

notesDepth3 =  Array.fill( 8, {
	arg i;
	var fn, subdirectory=instPath ++ peakDepths[2] ++ '/', groups, choice;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	groups = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	choice = groups.choose; // select random group from this depth
	notesDepth4[i].add(choice); // add choice
	choice;
});

// get freqs/amps for synths for 3 depths - SAME FOR BOTH VLN AND VC
// DEPTH 1
depth1Data = Array.fill( 8, {
	arg i;
	var fn, subdirectory=cwd ++ 'analyses/' ++ peakDepths[0] ++ '/peaks/', raw, freqs, amps;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	raw = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	freqs = raw[0];
	amps = raw[2];
	// correct amps to eliminate 0 for last item
	amps[7] = amps[6] * 0.9;
	amps[0] = amps[0] - amps[7]; // can probably get rid of this with downstream gain staging
	[freqs, amps]; // return
});
// DEPTH 2
depth2Data = Array.fill( 8, {
	arg i;
	var fn, subdirectory=cwd ++ 'analyses/' ++ peakDepths[1] ++ '/peaks/', raw, freqs, amps;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	raw = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	freqs = raw[0];
	amps = raw[2];
	// correct amps to eliminate 0 for last item
	amps[7] = amps[6] * 0.9;
	amps[0] = amps[0] - amps[7]; // can probably get rid of this with downstream gain staging
	[freqs, amps]; // return
});
// DEPTH 3
depth3Data = Array.fill( 8, {
	arg i;
	var fn, subdirectory=cwd ++ 'analyses/' ++ peakDepths[2] ++ '/peaks/', raw, freqs, amps;
	fn = subdirectory ++ degrees[i] ++ 'degrees.csv';
	raw = CSVFileReader.read(fn).collect(_.collect(_.interpret));
	freqs = raw[0];
	amps = raw[2];
	// correct amps to eliminate 0 for last item
	amps[7] = amps[6] * 0.9;
	amps[0] = amps[0] - amps[7]; // can probably get rid of this with downstream gain staging
	[freqs, amps]; // return
});


// BUILD WINDOW -----------------------------------------------------------------------------------
Window.closeAll;
w = Window(title, Rect(0, 200, wWidth, wHeight))
.front
.alwaysOnTop_(true);
w.onClose_( {
	switch( depths[facing],
			0, { synth1.set(\gate, 0) },
			1, { synth2.set(\gate, 0) },
			2, { synth3.set(\gate, 0) },
			3, { bufPlayers[facing].set(\gate, 0) }
		);
	facing=0;
	} );
w.view.decorator_(FlowLayout(w.bounds, 10@10, 10@10));


//w.background_(Color.new255(128, 200, 220));

// select eight colors
cards = Array.fill(8, {
	arg i;
	var cGroup=i.mod(3), color, dotColor, hueAlter;
	switch ( cGroup,
		0, { color = rgbs[rrand(0, 2)] }, //SOMETHING BLUE
		1, { color = rgbs[rrand(3, 4)] }, // SOMETHING LIGHT
		2, { color = rgbs[rrand(5, 7)] }, // SOMETHING RED
		{ "SOMETHING ELSE".postln } // should not execute
	);
	dotColor = color.copy;
	hueAlter = rrand(0, 2);
	if( hueAlter < 1.1 and:{hueAlter > 1.0}, { hueAlter = hueAlter + 0.1 });
	if( hueAlter < 1.0 and:{ hueAlter > 0.9}, { hueAlter = hueAlter - 0.1 });
	dotColor[hueAlter] = dotColor[hueAlter] * rrand(0.2, 2.0); // will this val need to get rounded?
	if( dotColor[hueAlter] > 255, { dotColor[hueAlter] = 255 });
	dots.put(i, dotColor); // put dotColor in dots arraya
	color; // return color to cards array
});

// make three views (L/facing/R)
views = Array.fill(3, {
	arg i;
	var view, color=cards[i];
	//["THIS COLOR", i, color].postln;
	view = UserView(w, vWidth@(wHeight-20))
	.background_(Color.new255(color[0], color[1], color[2]));
});


// function to update view background color
setViewsColors = {
	arg centerPane, views, cardColors;
	var i=centerPane-1;
	if( i < 0, { i = 7 } );
	//"REDRAWING".postln;
	views.do( {
		arg view;
		view.background_(Color.new255(cardColors[i][0], cardColors[i][1], cardColors[i][2]));
		i = i + 1;
		if( i > 7, { i = 0 });
	});
};

// a label for each view, will display degree value (direction facing)
labels = Array.fill(3, {
	arg i;
	var label;
	label = StaticText(views[i], Rect(vWidth/2-70, 10, 140, 11)).string_("DIRECTION")
	.font_(Font("Monaco", 14))
	.align_(\center);
});

// instrument string data
// I think I can get rid of these 6 lines—don't get rid of frets
// tune to A=441 Hz
if( instrument == "VIOLIN", { instStrings = [ 441*1.5, 441, 441/1.5, 441/1.5/1.5 ] }, { instStrings = [ 220.5, 220.5/1.5, 220.5/1.5/1.5, 220.5/1.5/1.5/1.5] });
instStrings = instStrings.reverse; // go IV -> I
instStringsRange = instStrings.collect( {
	arg freq;
	freq*2; // will display the lowest octave for each string
});

//
frets = [1, 3/2, 2/1]; // a "fret" will display at the nut, the fifth, and the octave

// add drawing function for each view
views.do( {
	arg view, i;
	view.drawFunc = {
		var v=i-1, dot_i=facing-1+i, labelString;
		if( dot_i < 0, { dot_i = 7 } );
		if( dot_i > 7, { dot_i = 0 } );
		//["V IS", v].postln;
		Pen.strokeColor = Color.black;
		Pen.width_(3);
		// draw horizontal frets

		frets.do( {
			arg fret;
			var x=stringPad, xEnd=stringGap*4, y, freq;
			freq = instStrings[0] * fret;
			y = freq.explin(instStrings[0], instStrings[0]*2, padding, padding+stringHeight);
			Pen.moveTo( x@y );
			Pen.lineTo( xEnd@y );
			Pen.fillStroke;
		});
		// positions captures the current finger positions from vlnFreqs (1D array from 2D array)
		position_i = facing + v;
		if( position_i < 0, { position_i = 7} );
		if( position_i > 7, { position_i = 0} );

		// logic here for selecting from the right file
		// notesDepth___[x] // 0-7 (facing)
		// notesDepth___[x][y] // which group

		switch ( depths[position_i],
			0, { positions = notesDepth1[position_i] },
			1, { positions = notesDepth2[position_i] },
			2, { positions = notesDepth3[position_i] },
			3, { positions = notesDepth4[position_i].choose }, //choose a random harmony group from what's available
			{ "TOO HIGH".postln; }
		);

		["POSITIONS", positions].postln;


		labelString = degreeLabels[position_i] ++ " DEPTH: " ++ (depths[position_i]+1).asString;
		labels[i].string_(labelString);
		// now draw string and finger location
		4.do( {
			arg i;
			var freq, x, y;
			x = (i * stringGap) + stringPad;
			freq = positions[i];
			//if( freq == 0, { freq = 0.1 });
			y = freq.explin(instStrings[i], instStrings[i]*2, padding, padding+stringHeight); // MUST FIGURE OUT HOW TO ALLOW FOR NOTES HIGHER THAN OCTAVE
			// draw the string
			Pen.fillColor = Color.new255(dots[dot_i][0], dots[dot_i][1], dots[dot_i][2]);
			Pen.strokeColor = Color.blue;
			Pen.moveTo( x@padding);
			Pen.lineTo( x@(stringHeight+50 + padding) );
			Pen.fillStroke;
			// draw a circle for finger location IF NOTE
			if( freq != 0, {
				Pen.addArc( x@y, 10, 2pi, 2pi);
				Pen.perform(\fill);
			});
	});
}});

// AUDIO --------------------------------------------------------------------------------------

// SYNTH DEFS ----------------------------------------------------------------------------------
/* SYNTH STRUCTURE:
1 sinBank8 (Depth 1)
1 sinBank64 (Depth 2)
1 sinBank512 (Depth 3)
8 bufPlays (one for each raw sound file (Depth 4)
bufPlays are gate controlled turning on/off for each station
sinBanks are updated with freqs so each depth works for all stations
*/
// make one synthDef for each depth size
// DEPTH 1
SynthDef.new(\sinBank8, {
	arg gate=0, out=0, amp=0.9;
	var size=8, sig, phases, amps, env, freqs, specs, time=rampTime;
	phases = Array.fill( size, { arg i; (i*rrand(-1.0, 1.0)).mod(2pi) }); // phase offset, try mod'ing if cycle is too obvious
	freqs = Array.fill( size, { 440 });
	amps = Array.fill( size, { 1/size });
	env = EnvGen.kr(Env.asr( time, 1.0, time ), gate);
	sig = SinOsc.ar(NamedControl.kr(\freqs1, freqs), phases, NamedControl.kr(\amps1, amps));
	// not sure about this filtering but will leave for now
	//sig = BHiShelf.ar(sig, 150, 1.0, -6);
	//sig = BHiShelf.ar(sig, 300, 1.0, -6);
	//sig = BHiShelf.ar(sig, 450, 1.0, -6);
	// ----------------------------------------------------
	sig = Mix.ar( sig ); // mix down to 1 channels
	sig = Pan2.ar(sig); //  now to 2 channels? need to see what studio setup will be
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
// DEPTH 2
SynthDef.new(\sinBank64, {
	arg gate=0, out=0, amp=1.0;
	var size=64, sig, phases, amps, env, freqs, specs, time=rampTime;
	phases = Array.fill( size, { arg i; (i*rrand(-1.0, 1.0)).mod(2pi) }); // phase offset, try mod'ing if cycle is too obvious
	freqs = Array.fill( size, { 440 });
	amps = Array.fill( size, { 1/size });
	env = EnvGen.kr(Env.asr( time, 1.0, time ), gate);
	sig = SinOsc.ar(NamedControl.kr(\freqs2, freqs), phases, NamedControl.kr(\amps2, amps));
	// not sure about this filtering but will leave for now
	//sig = BHiShelf.ar(sig, 150, 1.0, -6);
	//sig = BHiShelf.ar(sig, 300, 1.0, -6);
	//sig = BHiShelf.ar(sig, 450, 1.0, -6);
	// ----------------------------------------------------
	sig = Mix.ar( sig ); // mix down to 1 channels
	sig = Pan2.ar(sig); //  now to 2 channels? need to see what studio setup will be
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
// DEPTH 3
SynthDef.new(\sinBank512, {
	arg gate=0, out=0, amp=1.0;
	var size=512, sig, phases, amps, env, freqs, specs, time=rampTime;
	phases = Array.fill( size, { arg i; (i*rrand(-1.0, 1.0)).mod(2pi) }); // phase offset, try mod'ing if cycle is too obvious
	freqs = Array.fill( size, { 440 });
	amps = Array.fill( size, { 1/size });
	env = EnvGen.kr(Env.asr( time, 1.0, time ), gate);
	sig = SinOsc.ar(NamedControl.kr(\freqs3, freqs), phases, NamedControl.kr(\amps3, amps));
	// not sure about this filtering but will leave for now
	//sig = BHiShelf.ar(sig, 150, 1.0, -6);
	//sig = BHiShelf.ar(sig, 300, 1.0, -6);
	//sig = BHiShelf.ar(sig, 450, 1.0, -6);
	// ----------------------------------------------------
	sig = Mix.ar( sig ); // mix down to 1 channels
	sig = Pan2.ar(sig); //  now to 2 channels? need to see what studio setup will be
	sig = sig * env * amp;
	Out.ar(out, sig);
}).add;
// DEPTH 4: buffer synth def
SynthDef.new(\bufPlay, {
	arg buf=0, rate=1, t_trig, startPos=0, loop=0, da=2, amp=0.5, gate=0, pan=0, out=0;
	var sig, env, time=0.01;
	// build env
	env = EnvGen.kr( Env.asr(time, 1, time),
		gate: gate
		);
	sig = PlayBuf.ar(
		1,
		buf,
		BufRateScale.ir(buf) * rate,
		t_trig=1,
		startPos,
		loop,
		da
		);
	sig = sig * amp * env;
	sig = Pan2.ar(sig, pan);
	Out.ar(out, sig);
}).add;

// FILE HANDLING ----------------------------------------------------------------------------------
// get audio filenames
audioPath = PathName.new(thisProcess.nowExecutingPath).parentPath ++ "audio/trimmed/mono/";
audioFileNames = Array.new(8);
Array.series(8, 0, 45).collect( {
	arg i;
	var fname=audioPath++i.asString++"degrees.wav";
	audioFileNames.insert(i, fname);
	});

// build audio buffers
Buffer.freeAll; // free anything that's already allocated

bufs = audioFileNames.collect( {
	arg filename;
	var buf;
	// read in audio to buffer
	buf = Buffer.read(s, filename);
	});

// build bufPlay synths
fork{ 1.0.wait;
	bufPlayers = bufs.collect( {
		arg buf;
		//buf.numChannels.postln;
		Synth.new(\bufPlay, [
			\buf, buf.bufnum,
			\t_trig, 0,
			\loop, 1,
			//\pan, pans[buf.bufnum]
		])
	});
};

// build 3 synths
synth1 = Synth.new(\sinBank8, [\amp, 0.07]);
synth2 = Synth.new(\sinBank64, [\amp, 1.15]);
synth3 = Synth.new(\sinBank512, [\amp, 2.0]);

// initialize to Depth 1, 0 degrees, audio ON
synth1.setn(\freqs1, depth1Data[facing][0], \amps1, depth1Data[facing][1], \gate, 1);

w.view.keyDownAction = {
	arg view, char, modifiers, unicode, keycode;
	//[char, modifiers, unicode, keycode].postln;
	keycode.postln;
	if( (keycode == leftKey or:{ keycode == pedalLeft}), {
		"LEFT".postln;
		// turn off current synth or buffer
		switch ( depths[facing],
			0, { synth1.set(\gate, 0) }, // turn off sinBank8
			1, { synth2.set(\gate, 0) }, // turn off sinBank64
			2, { synth3.set(\gate, 0) }, // turn off sinBank512
			3, { bufPlayers[facing].set(\gate, 0 ) } // turn off buffer
		);

		// update depth for the position you just left
		depths[facing] = depths[facing] + 1;
		if( depths[facing] == 4, { depths[facing] = 0 }); // reset depth for now, but how to end the piece?
		// now update facing to the new position
		if( facing == 0, { facing=7 }, { facing=facing-1 });
		// turn on new synth or buffer and set new data
		switch ( depths[facing],
			0, { fork{ rampTime.wait; synth1.setn(\freqs1, depth1Data[facing][0], depth1Data[facing][1]); synth1.set(\gate, 1)}; }, // set and turn on sinBank8
			1, { fork{ rampTime.wait; synth2.setn(\freqs2, depth2Data[facing][0], depth2Data[facing][1]); synth2.set(\gate, 1)}; }, // set and turn on sinBank64
			2, { fork{ rampTime.wait; synth3.setn(\freqs3, depth3Data[facing][0], depth3Data[facing][1]); synth3.set(\gate, 1)}; }, // set and turn on sinBank512
			3, { fork{ 0.001.wait; bufPlayers[facing].set(\gate, 1)}; } // turn on new buffer
		);
		//facing.postln;
		setViewsColors.(facing, views, cards);
		views.do( { arg view; view.refresh; });
	});

	if( (keycode == rightKey or:{ keycode == pedalRight}), {
		"RIGHT".postln;
		// turn off current synth or buffer
		switch ( depths[facing],
			0, { synth1.set(\gate, 0) }, // turn off sinBank8
			1, { synth2.set(\gate, 0) }, // turn off sinBank64
			2, { synth3.set(\gate, 0) }, // turn off sinBank512
			3, { bufPlayers[facing].set(\gate, 0 ) } // turn off buffer
		);
		// update depth for the position you just left
		depths[facing] = depths[facing] + 1;
		if( depths[facing] == 4, { depths[facing] = 0 });
		// now update facing to the new position
		if( facing == 7, { facing=0 }, { facing=facing+1 });
		// turn on new synth or buffer and set new data
		switch ( depths[facing],
			0, { fork{ rampTime.wait; synth1.setn(\freqs1, depth1Data[facing][0], depth1Data[facing][1]); synth1.set(\gate, 1)}; }, // set and turn on sinBank8
			1, { fork{ rampTime.wait; synth2.setn(\freqs2, depth2Data[facing][0], depth2Data[facing][1]); synth2.set(\gate, 1)}; }, // set and turn on sinBank64
			2, { fork{ rampTime.wait; synth3.setn(\freqs3, depth3Data[facing][0], depth3Data[facing][1]); synth3.set(\gate, 1)}; }, // set and turn on sinBank512
			3, { fork{ 0.001.wait; bufPlayers[facing].set(\gate, 1)}; } // turn on new buffer
		);
		//facing.postln;
		setViewsColors.(facing, views, cards);
		views.do( { arg view; view.refresh; });
		});
	if( keycode == xKey, {
		// x will kill all sound
		synth1.setn(\gate, 0);
		synth2.setn(\gate, 0);
		synth3.setn(\gate, 0);
		bufPlayers.do( {arg n; n.set(\gate, 0) });
	});
	if( keycode == oKey, {
		// o will turn on ~facing buffer if off
		switch( depths[facing],
			0, { synth1.set(\gate, 1) },
			1, { synth2.set(\gate, 1) },
			2, { synth3.set(\gate, 1) },
			3, { bufPlayers[facing].set(\gate, 1) }
		);
	});
};

//s.meter;
)

s.plotTree;
s.freeAll;