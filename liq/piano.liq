#!/home/pi/.opam/5.3.0/bin/liquidsoap

settings.log.file := true
settings.log.file.path := "/home/pi/piano.log"
settings.log.level := 2
## 2 : important
## 3 : normal
## 4 : information
## 5 : debug

## Settings

enable_replaygain_metadata()
#settings.lufs.track_gain_target:=-18.0
#enable_lufs_track_gain_metadata()
#enable_autocue_metadata()
#settings.audio.converter.samplerate.libsamplerate.quality := "best"
#settings.audio.converter.samplerate.native.quality := "nearest"
settings.decoder.file_extensions.flac_metadata := ["flac"]
settings.decoder.file_extensions.flac := ["flac"]
settings.decoder.file_extensions.id3 := ["mp3", "flac"]
settings.encoder.metadata.export := ["artist", "title", "album", "genre", "date", "composer", "year","metadata_block_picture"]
settings.frame.audio.samplerate := 44100
settings.frame.audio.channels := 2
settings.charset.encodings := ["UTF-8"]
settings.charset.max_string_length := 2048
settings.clock.latency := 0.5

settings.alsa.alsa_buffer := 4096
settings.alsa.periods := 2

## log

l = playlog(duration=86400.)

def checker(r)
  m = request.metadata(r)
  if l.last(m) < 86000. then
    log.info("Rejecting #{m['filename']} (played #{l.last(m)}s ago).")
    false
  else
    l.add(m)
    true
  end
end

## Catalog by genre

#classicbaroque          = playlist("/mnt/PIANO/PIANO_sorted/CLASSIC-BAROQUE/",mode="randomize",reload_mode="watch")
#contemporarymodern      = playlist("/mnt/PIANO/PIANO_sorted/CONTEMPORARY-MODERN/",mode="randomize",reload_mode="watch")
noise_                  = replaygain(playlist("/mnt/PIANO/PIANO_sorted/NOISE/",mode="randomize",reload_mode="watch"))
exoticambiant           = replaygain(playlist("/mnt/PIANO/PIANO_sorted/EXOTIC-AMBIANT/",mode="randomize",reload_mode="watch"))
jazz			= replaygain(playlist("/mnt/PIANO/PIANO_sorted/JAZZ/",mode="randomize",reload_mode="watch"))
minimalismavantgarde    = replaygain(playlist("/mnt/PIANO/PIANO_sorted/MINIMALISM-AVANTGARDE/",mode="randomize",reload_mode="watch"))
modernclassical         = replaygain(playlist("/mnt/PIANO/PIANO_sorted/MODERNCLASSICAL/",mode="randomize",reload_mode="watch"))
nightclub               = replaygain(playlist("/mnt/PIANO/PIANO_sorted/NIGHTCLUB/",mode="randomize",reload_mode="watch"))
vocals			= replaygain(playlist("/mnt/PIANO/PIANO_sorted/VOCALS/",mode="randomize",reload_mode="watch"))
impro 			= replaygain(playlist("/mnt/PIANO/PIANO_sorted/IMPROVISATION/",mode="randomize",reload_mode="watch"))
#,check_next=checker))

## Schedule

pianoday   = random( [  vocals, exoticambiant, minimalismavantgarde, jazz, modernclassical,impro   ])
pianonight = random( [  vocals, noise_, exoticambiant, nightclub, minimalismavantgarde  ])

# rotate(weights = [5,1],[bla,bli])

piano = fallback([ switch([     ( { 8h-20h}, pianoday ), ( { 20h-8h}, pianonight )      ])      ])

piano.on_metadata(synchronous=true, fun (m) -> ignore(file.write(data="#{m[\"artist\"]} - #{m[\"title\"]}\n", append=true, "/mnt/PIANO/PIANO_sorted/playlist.txt")) )

piano = crossfade(start_duration=0.5,end_duration=0.5, duration = 1.0, fade_out = 0.5, fade_in = 0.5,piano ) 

piano = mksafe(piano)

## modify metadata for icecast / mp3

def append_title(m) =
  title = m["title"]
  date = m["date"]
  if m["composer"] != ""
  then 
	composer = m["composer"]
	[( "title","#{title}, composed by #{composer} | #{date}" )]
  else
	[( "title","#{title} (#{date})" )]
  end
end

pianomp3  = metadata.map(append_title, piano)

## output FLAC > P-NODE

output.icecast(
	%ogg(%flac(samplerate=44100,
        	channels=2,
        	compression=5,
        	bits_per_sample=16)
	),
        host="stream.p-node.org",
        port=80,
        password="!pianosolo!",
        mount="/piano",
        fallible=true,
        description="Endless Stream of Piano",
        name="∏ano",
        url="https://p-node.org/piano",
        genre="Archive",
#        icy_metadata="false",
        format="audio/ogg",
#	fallible = true,
 piano)


# output MP3 320 > P-NODE

output.icecast(%mp3(bitrate=320,samplerate=44100,stereo=true,stereo_mode="stereo",id3v2=true),
        host = "stream.p-node.org",
        port = 80, 
	password = "!pianosolo!",
        mount = "/piano.mp3", 
        description = "Endless Stream of Piano",
        name = "∏ano",
        url = "https://p-node.org/piano",
        genre = "Archive",
	send_icy_metadata =  true,
        icy_metadata = ["song", "title", "artist", "genre", "composer"],
#        fallible = true,
      pianomp3)

### OUTPUT TO Hi-Fi ################################
#output.alsa(self_sync=true,device="hw:1,0",piano)

#########################################################"""
