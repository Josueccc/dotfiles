function ytaudio --description "Download best native-quality audio (no lossy re-encode), saved to ~/Music"
    if test (count $argv) -lt 1
        echo "Usage: ytaudio <url> [extra yt-dlp args...]"
        return 1
    end

    yt-dlp \
        -x --audio-quality 0 \
        --embed-thumbnail --embed-metadata \
        -o "$HOME/Music/%(title)s.%(ext)s" \
        $argv
end
