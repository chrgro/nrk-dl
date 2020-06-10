param (
    [Parameter(Mandatory, Position = 0)]
    [string]
    $Name,

    [Parameter()]
    [switch]
    $DropVideo,

    [Parameter()]
    [switch]
    $DropSubtitles,

    [Parameter()]
    [switch]
    $DropImages,

    [Parameter()]
    [switch]
    $LegacyFormatting
)

function Format-Name {
    param (
        [Parameter(Mandatory)]
        [string]
        $Name
    )
    $output = $Name
    $output = $output -replace "\?"
    $output = $output -replace ":"
    $output = $output -replace [char]0x0021 # !
    $output = $output -replace [char]0x0022 # "
    $output = $output -replace "\*"
    $output = $output -replace "/"
    $output = $output -replace '\\'
    return $output
}

function Get-Episodeinfo {
    $season_filename = "{0:d2}" -f ([int]$season)
    $season_dirname = "Season " + "$season_filename"
    $episode_title = Format-Name -Name ($episode_raw.titles.title)
    if ($episode_raw.sequenceNumber) {
        $seq_num = "{0:d2}" -f ($episode_raw.sequenceNumber)
    }
    $episode_manifest = Invoke-RestMethod -Uri ("https://psapi.nrk.no/playback/manifest/program/" + $episode_raw.prfId)

    if (!($DropVideo)) {
        $global:episodes += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'url'=$episode_raw._links.share.href;'url_fallback'=$episode_manifest.playable.assets.url;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
    }

    if (!($DropSubtitles)) {
        if ($episode_manifest.playable.subtitles.Count -gt 1) {
            Write-Warning ($episode_raw.prfId + " har mer enn 1 subtitle (" + $episode_manifest.playable.subtitles.Count + " subtitles), gjerne dobbelsjekk subtitles")
        }
        foreach ($sub in $episode_manifest.playable.subtitles) {
            $global:subtitles += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'language'=$sub.language;'forced'=$sub.defaultOn;'url'=$sub.webVtt;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }

    if (!($DropImages)) {
        $episode_image = $null
        $episode_image = ($episode_raw.image | Sort-Object -Property width -Descending).url[0]
        if ($episode_image) {
            $global:images += New-Object -TypeName "PSObject" -Property @{'id'=$episode_raw.prfId;'url'=$episode_image;'title'=$episode_title;'date'=$episode_raw.firstTransmissionDateDisplayValue;'seasonfn'="$season_filename";'seasondn'="$season_dirname";'seq_num'="$seq_num"}
        }
    }
}

$ProgressPreference = 'SilentlyContinue'
$root_location = Get-Location

if (!(Test-Path -PathType "Leaf" -Path "youtube-dl.exe")) {
    Write-Output "Downloading youtube-dl"
    Invoke-WebRequest -Uri "https://youtube-dl.org/downloads/latest/youtube-dl.exe" -OutFile "youtube-dl.exe"
    Write-Output "Downloaded youtube-dl"
}

if (!(Test-Path -PathType "Leaf" -Path "ffmpeg.exe")) {
    Write-Output "Downloading ffmpeg"
    Invoke-WebRequest -Uri "https://cdn.serverhost.no/ljskatt/ffmpeg.exe" -OutFile "ffmpeg.exe"
    Write-Output "Downloaded ffmpeg"
}

if (!(Test-Path -PathType "Container" -Path "downloads")) {
    New-Item -ItemType "Directory" -Path "downloads" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads") {
        Write-Output "Opprettet downloads mappe"
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object "Kunne ikke opprette downloads mappe"
        exit
    }   
}

$seasons = $null
$standalone = $null
$series_req = Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/series/$name"
$seasons = $series_req._links.seasons.name
if ($seasons) {
    if (!($DropImages)) {
        if ($series_req.sequential.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.sequential.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.standard.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req.news.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.backdropImage -ne $null) {
            $series_backdrop_url = ($series_req._embedded.seasons.backdropImage | Sort-Object -Property width -Descending).url[0]
        }
        else {
            Write-Warning "Kunne ikke finne serie-backdrop"
        }

        if ($series_req.sequential.posterImage -ne $null) {
            $series_poster_url = ($series_req.sequential.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.posterImage -ne $null) {
            $series_poster_url = ($series_req.standard.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.posterImage -ne $null) {
            $series_poster_url = ($series_req.news.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.posterImage -ne $null) {
            $series_poster_url = ($series_req._embedded.seasons.posterImage | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.sequential.image -ne $null){
            $series_poster_url = ($series_req.sequential.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.standard.image -ne $null) {
            $series_poster_url = ($series_req.standard.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req.news.image -ne $null) {
            $series_poster_url = ($series_req.news.image | Sort-Object -Property width -Descending).url[0]
        }
        elseif ($series_req._embedded.seasons.image -ne $null) {
            $series_poster_url = ($series_req._embedded.seasons.image | Sort-Object -Property width -Descending).url[0]
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object "Kunne ikke finne serie-poster"
        }
    }
    $type = "series"
    $seriestype = $series_req.seriesType

    if ($series_req.sequential.titles.title) {
        $seriestitle = Format-Name -Name ($series_req.sequential.titles.title)
    }
    elseif ($series_req.standard.titles.title) {
        $seriestitle = Format-Name -Name ($series_req.standard.titles.title)
    }
}
else {
    $standalone_req = (Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/programs/$name")
    $standalone = $standalone_req._links.share.href
    if ($standalone_req) {
        $type = "standalone"
    }
    else {
        Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object "Kunne ikke finne program/serie"
        exit
    }
}

Write-Output "----------" "" "$name (Type: $type)" "Download folder: $root_location\downloads\$name" ""
Write-Host "Video:             " -NoNewline
if ($DropVideo) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF "
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON "
}

Write-Host "Images:            " -NoNewline
if ($DropImages) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF "
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON "
}

Write-Host "Subtitles:         " -NoNewline
if ($DropSubtitles) {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF "
}
else {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON "
}

Write-Host "Legacy Formatting: " -NoNewline
if ($LegacyFormatting) {
    Write-Host -BackgroundColor "Green" -ForegroundColor "Black" -Object " ON "
}
else {
    Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object " OFF "
}

Write-Output "" "----------"
Read-Host -Prompt "Press enter to continue, CTRL + C to quit"

if (!(Test-Path -PathType "Container" -Path "downloads/$name")) {
    New-Item -ItemType "Directory" -Path "downloads/$name" | Out-Null
    if (Test-Path -PathType "Container" -Path "downloads/$name") {
        Write-Output "Opprettet $name mappe"
    }
    else {
        Write-Warning "Kunne ikke opprette $name mappe"
        exit
    }
}
Set-Location -Path "downloads/$name"

if ($type -eq "standalone") {
    if (!($DropVideo)) {
        $standalone = $standalone -replace '{&autoplay,t}', ''
        Write-Output "Video: Downloading"
        & "$root_location\youtube-dl.exe" "$standalone"
        Write-Output "Video: Downloaded"
    }
    if (!($DropSubtitles)) {
        $subtitles = (Invoke-RestMethod -Uri "https://psapi.nrk.no/playback/manifest/program/$name").playable.subtitles
        Write-Output "Subtitles: Downloading"
        if ($subtitles.Count -gt 1) {
            Write-Warning ("$name har mer enn 1 subtitle (" + $subtitles.Count + " subtitles), gjerne dobbelsjekk subtitles")
        }
        foreach ($subtitle in $subtitles) {
            if ($subtitle.defaultOn -eq $true) {
                $sub_forced = ".forced"
            }
            else {
                $sub_forced = ""
            }
            Invoke-WebRequest -Uri ($subtitle.webVtt) -OutFile ("$name" + "." + $subtitle.language + "$sub_forced.vtt")
        }
        Write-Output "Subtitles: Done"
    }
    if (!($DropImages)) {
        Write-Output "Images: Downloading"
        if ($standalone_req.programInformation.backdropImage) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.backdropImage | Sort-Object -Property width -Descending).url[0]) -OutFile "background.jpg"
        }
        if ($standalone_req.programInformation.posterImage) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.posterImage | Sort-Object -Property width -Descending).url[0]) -OutFile "poster.jpg"
        }
        elseif ($standalone_req.programInformation.image) {
            Invoke-WebRequest -Uri (($standalone_req.programInformation.image | Sort-Object -Property width -Descending).url[0]) -OutFile "poster.jpg"
        }
        else {
            Write-Host -BackgroundColor "Red" -ForegroundColor "Black" -Object "Could not find poster"
        }
        Write-Output "Images: Done"
    }
}

if ($type -eq "series") {
    $global:episodes = @()
    $global:subtitles = @()
    if (!($DropImages)) {
        $global:images = @()
        if ($series_backdrop_url) {
            Invoke-WebRequest -Uri "$series_backdrop_url" -OutFile "background.jpg"
        }
        if ($series_poster_url) {
            Invoke-WebRequest -Uri "$series_poster_url" -OutFile "poster.jpg"
        }
    }
    foreach ($season in $seasons) {
        $episodes_req = Invoke-RestMethod -Uri "https://psapi.nrk.no/tv/catalog/series/$name/seasons/$season"
        foreach ($episode_raw in $episodes_req._embedded.episodes) {
            Get-Episodeinfo
        }

        foreach ($episode_raw in $episodes_req._embedded.instalments) {
            Get-Episodeinfo
        }
    }

    $episodes = $global:episodes
    $subtitles = $global:subtitles
    $images = $global:images

    if (!($DropVideo)) {
        $episodes_count = $episodes.Count
        $download_count = 0
        foreach ($episode in $episodes) {
            $download_count += 1
            if (!(Test-Path -PathType "Container" -Path ($episode.seasondn))) {
                New-Item -ItemType "Directory" -Path ($episode.seasondn) | Out-Null
            }
            Write-Output "" "Downloading ($download_count/$episodes_count)"
            $episode.url = $episode.url -replace '{&autoplay,t}', ''

            if (($seriestype -eq "sequential") -and (!($LegacyFormatting))) {
                $outfile = ($episode.seasondn + "/$seriestitle - s" + $episode.seasonfn + "e" + $episode.seq_num + ".mp4")
            }
            elseif (($episode.date) -and (!($LegacyFormatting))) {
                $outfile = ($episode.seasondn + "/$seriestitle - " + $episode.date + " - " + $episode.title + ".mp4")
            }
            else {
                $outfile = ($episode.seasondn + "/$name - " + $episode.id + ".mp4")
            }

            if (Test-Path -PathType "Leaf" -Path "$outfile") {
                Write-Output "Episode exists: $outfile"
            }
            else {
                & "$root_location\youtube-dl.exe" -q ($episode.url) -o "$outfile"
                if (Test-Path -PathType "Leaf" -Path "$outfile") {
                    Write-Output "Downloaded ($download_count/$episodes_count)"
                }
                else {
                    Write-Warning "Download failed, trying fallback url"
                    & "$root_location\youtube-dl.exe" -q ($episode.url_fallback) -o "$outfile"
                    if (Test-Path -PathType "Leaf" -Path "$outfile") {
                        Write-Output "Downloaded ($download_count/$episodes_count)"
                    }
                    else {
                        Write-Host -BackgroundColor "red" -ForegroundColor "black" -Object ("Nedlasting av " + $episode.id + " feilet")
                    }
                }
            }
            
        }
    }
    if (!($DropSubtitles)) {
        Write-Output "" ""
        $subtitles_count = $subtitles.Count
        $sub_dl_count = 0
        foreach ($subtitle in $subtitles) {
            $sub_dl_count += 1
            Write-Output "Downloading subtitle ($sub_dl_count/$subtitles_count)"

            if ($subtitle.defaultOn -eq $true) {
                $sub_forced = ".forced"
            }
            else {
                $sub_forced = ""
            }

            if (!(Test-Path -PathType "Container" -Path ($subtitle.seasondn))) {
                New-Item -ItemType "Directory" -Path ($subtitle.seasondn) | Out-Null
            }

            if (($seriestype -eq "sequential") -and (!($LegacyFormatting))) {
                $outfile = ($subtitle.seasondn + "/$seriestitle - s" + $subtitle.seasonfn + "e" + $subtitle.seq_num + "." + $subtitle.language + "$sub_forced.vtt")
            }
            elseif (($subtitle.date) -and (!($LegacyFormatting))) {
                $outfile = ($subtitle.seasondn + "/$seriestitle - " + $subtitle.date + " - " + $subtitle.title + "." + $subtitle.language + "$sub_forced.vtt")
            }
            else {
                $outfile = ($subtitle.seasondn + "/" + $subtitle.id + "." + $subtitle.language + "$sub_forced.vtt")
            }
            Invoke-WebRequest -Uri ($subtitle.url) -OutFile "$outfile"
        }
    }
    if (!($DropImages)) {
        Write-Output "" ""
        $images_count = $images.Count
        $img_dl_count = 0
        foreach ($image in $images) {
            $img_dl_count += 1
            Write-Output "Downloading image ($img_dl_count/$images_count)"
            if (!(Test-Path -PathType "Container" -Path ($image.seasondn))) {
                New-Item -ItemType "Directory" -Path ($image.seasondn) | Out-Null
            }

            if (($seriestype -eq "sequential") -and (!($LegacyFormatting))) {
                $outfile = ($image.seasondn + "/$seriestitle - s" + $image.seasonfn + "e" + $image.seq_num + ".jpg")
            }
            elseif (($image.date) -and (!($LegacyFormatting))) {
                $outfile = ($image.seasondn + "/$seriestitle - " + $image.date + " - " + $image.title + ".jpg")
            }
            else {
                $outfile = ($image.seasondn + "/" + $image.id + ".jpg")
            }
            Invoke-WebRequest -Uri ($image.url) -OutFile "$outfile"
        }
    }
}

Set-Location -Path "$root_location"