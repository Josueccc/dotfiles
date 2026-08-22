function ytmp3 --description "Download audio from a URL as MP3 (320kbps) with embedded cover art + metadata, saved to ~/Music"
    if test (count $argv) -lt 1
        echo "Usage: ytmp3 <url> [extra yt-dlp args...]"
        return 1
    end

    yt-dlp \
        -x --audio-format mp3 --audio-quality 0 \
        --embed-thumbnail --embed-metadata \
        -o "$HOME/Music/%(title)s.%(ext)s" \
        $argv
end
