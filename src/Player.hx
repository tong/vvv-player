
import js.html.SourceElement;
import js.Browser.console;
import js.Browser.document;
import js.Browser.window;
import js.html.AudioElement;
import js.html.VideoElement;
import js.html.CanvasElement;
import js.html.CanvasRenderingContext2D;
import js.html.audio.AnalyserNode;
import js.html.audio.AudioContext;
import js.lib.Promise;
import js.lib.Uint8Array;
import om.FetchTools;

typedef Config = {
    var host : String;
    var port : Int;
    //var status_path : String;
}

class Player {

    static var config(default,null) : Config;

    public static var mount(default,null) : String;

    static var audio : AudioElement;
    static var sourceElement : SourceElement;
    static var analyser : AnalyserNode;
    static var animationFrameId : Int;
    static var timeData : Uint8Array;
	static var freqData : Uint8Array;
	static var canvas : CanvasElement;
    static var graphics : CanvasRenderingContext2D;

    @:expose("Player.init")
    static function init( config : Config ) : Promise<Dynamic> {
        trace( "Player init " +config );
        Player.config = config;
        return fetchStats().then( stats -> {

            audio = document.createAudioElement();
            audio.preload = "none";
            audio.crossOrigin = "anonymous";
            audio.controls = false;
            audio.autoplay = true;
    
            sourceElement = document.createSourceElement();
            audio.appendChild( sourceElement );

            canvas = cast document.getElementById("spectrum");
            graphics = canvas.getContext("2d");
            animationFrameId = window.requestAnimationFrame( update );

            return stats;
        });
    }

    @:expose("Player.fetchStats")
    static function fetchStats() : Promise<Dynamic> {
        var url = 'http://${config.host}:${config.port}';
        return FetchTools.fetchJson( '$url/status-json.xsl' ).then( data -> {
           return data.icestats;
        });
    }

    @:expose("Player.play")
    static function play( source : Dynamic ) {

        trace("Player.play",source);

        if( audio != null ) {
            audio.pause();
        }

        sourceElement.type = source.server_type;
        sourceElement.src = source.listenurl;

        if( analyser == null ) {

            var audioContext = new AudioContext();
            if( audioContext == null ) audioContext = js.Syntax.code( 'new window.webkitAudioContext()' );
            analyser = audioContext.createAnalyser();
            analyser.fftSize = 2048;
            analyser.connect( audioContext.destination );
    
            freqData = new Uint8Array( analyser.frequencyBinCount );
            timeData = new Uint8Array( analyser.frequencyBinCount );
    
            var source = audioContext.createMediaElementSource( audio );
            source.connect( analyser );
        }

        audio.load();
        audio.play();
    }

    @:expose("Player.pause")
    static function pause() {
        if( audio != null ) {
            audio.pause();
        }
    }

    static function update( time : Float ) {

		animationFrameId = window.requestAnimationFrame( update );

        if( analyser != null ) {

            analyser.getByteTimeDomainData( timeData );
            analyser.getByteFrequencyData( freqData );
    
            var x = 0, y = 0;
    
            graphics.clearRect( 0, 0, canvas.width, canvas.height );
    
            graphics.fillStyle = "#000000";
            graphics.strokeStyle = "#ffffff";
            graphics.lineWidth = 1;

            graphics.fillRect( 0, 0, canvas.width, canvas.height );
    
            var sliceWidth = canvas.width * 1.0 / analyser.frequencyBinCount;
            var cy = canvas.height / 2;
            var px = 0.0, py = 0.0;
            graphics.beginPath();
            for( i in 0...analyser.frequencyBinCount ) {
                var v = timeData[i] / 128.0;
                py = v * cy;
                if( i == 0 ) {
                    graphics.moveTo(px+x, py+y);
                } else {
                    graphics.lineTo(px+x, py+y);
                }
                px += sliceWidth;
            }
            //graphics.lineTo( w, centerY);
            graphics.stroke();
        }
    }
}
