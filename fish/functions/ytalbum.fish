function ytalbum --description "Download a playlist/album as numbered MP3s into ~/Music/<playlist name>/"
    if test (count $argv) -lt 1
        echo "Usage: ytalbum <playlist_url> [extra yt-dlp args...]"
        return 1
    end

    yt-dlp \
        -x --audio-format mp3 --audio-quality 0 \
        --embed-thumbnail --embed-metadata \
        -o "$HOME/Music/%(playlist_title)s/%(playlist_index)02d - %(title)s.%(ext)s" \
        $argv
end
