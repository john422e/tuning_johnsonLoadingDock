s.boot;
s.quit;



(
var title = "Johnson Museum Score";
// constants for VISUAL
var textPath, vlnFreqFile, vlnFreqs;
var degreeLabels, labels;
var wWidth=1540, wHeight=820, vWidth=(wWidth-40)/3, views;
var padding=30, stringHeight=700, stringGap=100, stringPad=100;
var a440=440, vlnStrings, vlnStringsRange, frets;
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
// mutables that will get updated through routine
var facing=0, position_i, positions;
// constants for AUDIO
var audioPath, audioFileNames, bufs, bufPlayers;
var pans; // for dev only
// HID STUFF ------------------------------------------
var leftKey=123, rightKey=124, xKey=7, oKey=31, pedalLeft=126, pedalRight=125;

// FILE HANDLING ----------------------------------------------------------------------------------
// read in csv file with instrument freqs for notation
textPath = PathName.new(thisProcess.nowExecutingPath).parentPath ++ "vlnFreqs.csv";
vlnFreqFile = CSVFileReader.read(textPath).postcs;
vlnFreqs = vlnFreqFile.collect(_.collect(_.interpret)); // converts into numbers
// strings for window views
degreeLabels = ['0°/360°', '45°', '90°', '135°', '180°', '225°', '270°', '315°'];

// BUILD WINDOW -----------------------------------------------------------------------------------
Window.closeAll;
w = Window(title, Rect(0, 200, wWidth, wHeight))
.front
.alwaysOnTop_(true);
w.view.decorator_(FlowLayout(w.bounds, 10@10, 10@10));
// make three views (L/facing/R)
views = Array.fill(3, {
	arg i;
	var view, color;
	if( i == 0, { color = rrand(0, 2) });
	if( i == 1, { color = rrand(3, 4) });
	if( i == 2, { color = rrand(5, 7) });
	i.postln;
	view = UserView(w, vWidth@(wHeight-20))
	.background_(Color.new255(rgbs[color][0], rgbs[color][1], rgbs[color][2]));
});
// a label for each view, will display degree value (direction facing)
labels = Array.fill(3, {
	arg i;
	var label;
	label = StaticText(views[i], Rect(vWidth/2-40, 10, 80, 11)).string_("DIRECTION")
	.font_(Font("Monaco", 14))
	.align_(\center);
});

// instrument string data
vlnStrings = [ 440*1.5, 440, 440/1.5, 440/1.5/1.5 ]; // pythag tuning at A=440
vlnStrings = vlnStrings.reverse; // go IV -> I
vlnStringsRange = vlnStrings.collect( {
	arg freq;
	freq*2; // will display the lowest octave for each string
});
frets = [1, 3/2, 2/1]; // a "fret" will display at the nut, the fifth, and the octave

// add drawing function for each view
views.do( {
	arg view, i;
	view.drawFunc = {
		var v=i-1;
		//["V IS", v].postln;
		Pen.strokeColor = Color.black;
		Pen.width_(3);
		// draw horizontal frets
		frets.do( {
			arg fret;
			var x=stringPad, xEnd=stringGap*4, y, freq;
			freq = vlnStrings[0] * fret;
			y = freq.explin(vlnStrings[0], vlnStrings[0]*2, padding, padding+stringHeight);
			Pen.moveTo( x@y );
			Pen.lineTo( xEnd@y );
			Pen.fillStroke;
		});
		// positions captures the current finger positions from vlnFreqs (1D array from 2D array)

		position_i = facing + v;
		if( position_i < 0, { position_i = 7} );
		if( position_i > 7, { position_i = 0} );
		//["FACING", position_i].postln;
		positions = vlnFreqs[position_i];
		labels[i].string_(degreeLabels[position_i]);
		// now draw string and finger location
		4.do( {
			arg i;
			var freq, x, y;
			x = (i * stringGap) + stringPad;
			freq = positions[i];
			y = freq.explin(vlnStrings[i], vlnStrings[i]*2, padding, padding+stringHeight);
			// draw the string
			Pen.fillColor = Color.red;
			Pen.strokeColor = Color.blue;
			Pen.moveTo( x@padding);
			Pen.lineTo( x@(stringHeight + padding) );
			Pen.fillStroke;
			// draw a circle for finger location
			Pen.addArc( x@y, 10, 2pi, 2pi);
			Pen.perform(\fill);
	});
}});

// AUDIO --------------------------------------------------------------------------------------

// SYNTH DEF ----------------------------------------------------------------------------------
// buffer synth def
SynthDef.new(\bufPlay, {
	arg buf=0, rate=1, t_trig, startPos=0, loop=0, da=2, amp=0.5, gate=0, pan=0, out=0;
	var sig, env;
	// build env
	env = EnvGen.kr( Env.asr(0.01, 1, 0.01),
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
Buffer.freeAll;
bufs = audioFileNames.collect( {
	arg filename;
	var buf;
	// read in audio to buffer
	buf = Buffer.read(s, filename);
	});

// DEV ONLY
pans = Array.series(8, -1.0, 0.285);
//
// build bufPlay synths
bufPlayers = bufs.collect( {
	arg buf;
	//buf.numChannels.postln;
	Synth.new(\bufPlay, [
		\buf, buf,
		\t_trig, 0,
		\loop, 1,
		\pan, pans[buf.bufnum]
		])
	});

//bufPlayers[0].set(\gate, 1);

w.view.keyDownAction = {
	arg view, char, modifiers, unicode, keycode;
	//[char, modifiers, unicode, keycode].postln;
	keycode.postln;
	if( (keycode == leftKey or:{ keycode == pedalLeft}), {
		"LEFT".postln;
		// turn off current buffer
		bufPlayers[facing].set(\gate, 0);
		if( facing == 0, { facing = 7 }, { facing = facing - 1 });
		// turn on new buffer
		bufPlayers[facing].set(\gate, 1);
		facing.postln;
		views.do( { arg view; view.refresh; });
		});

	if( (keycode == rightKey or:{ keycode == pedalRight}), {
		"RIGHT".postln;
		// turn off current buffer
		bufPlayers[facing].set(\gate, 0);
		if( facing == 7, { facing = 0 }, { facing = facing + 1 });
		// turn on new buffer
		bufPlayers[facing].set(\gate, 1);
		facing.postln;
		views.do( { arg view; view.refresh; });
		});
	if( keycode == xKey, {
		// x will kill all sound
		bufPlayers.do( {arg n; n.set(\gate, 0) });
	});
	if( keycode == oKey, {
		// o will turn on ~facing buffer if off
		bufPlayers[facing].set(\gate, 1);
	});
};
)
