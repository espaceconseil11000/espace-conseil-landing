$port = 3000
$root = $PSScriptRoot

$mimes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css'  = 'text/css; charset=utf-8'
    '.js'   = 'application/javascript; charset=utf-8'
    '.json' = 'application/json'
    '.png'  = 'image/png'
    '.jpg'  = 'image/jpeg'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

$tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
$tcp.Server.SetSocketOption('Socket','ReuseAddress',1)
$tcp.Start(10)
Write-Host "Serving http://localhost:$port/ from $root"

function Read-RequestLine($stream) {
    $sb   = [System.Text.StringBuilder]::new()
    $buf  = [byte[]]::new(1)
    $prev = 0
    while ($true) {
        $n = $stream.Read($buf, 0, 1)
        if ($n -eq 0) { break }
        $ch = [char]$buf[0]
        if ($prev -eq [char]"`r" -and $ch -eq "`n") {
            # skip rest of headers
            $header = [byte[]]::new(4096)
            $stream.ReadTimeout = 500
            try {
                while ($true) {
                    $r = $stream.Read($header, 0, $header.Length)
                    if ($r -eq 0) { break }
                    $chunk = [System.Text.Encoding]::ASCII.GetString($header, 0, $r)
                    if ($chunk -match "`r`n`r`n") { break }
                }
            } catch {}
            break
        }
        if ($ch -ne "`r") { [void]$sb.Append($ch) }
        $prev = $ch
    }
    return $sb.ToString()
}

while ($true) {
    try {
        $client = $tcp.AcceptTcpClient()
        $client.ReceiveTimeout = 5000
        $client.SendTimeout    = 10000
        $stream = $client.GetStream()
        $stream.ReadTimeout = 5000

        $line = Read-RequestLine $stream
        if (-not $line) { $client.Close(); continue }

        $parts   = $line -split ' '
        $method  = $parts[0]
        $rawPath = if ($parts.Count -ge 2) { $parts[1] } else { '/' }
        $urlPath = ($rawPath -replace '\?.*','') -replace '^/',''
        if ($urlPath -eq '') { $urlPath = 'index.html' }

        $filePath = Join-Path $root $urlPath
        Write-Host "$method /$urlPath"

        if ($method -eq 'HEAD') {
            $resp = "HTTP/1.1 200 OK`r`nContent-Length: 0`r`nConnection: close`r`n`r`n"
            $b = [System.Text.Encoding]::ASCII.GetBytes($resp)
            $stream.Write($b, 0, $b.Length)
            $stream.Flush()
        } elseif (Test-Path $filePath -PathType Leaf) {
            $ext  = [System.IO.Path]::GetExtension($filePath)
            $mime = if ($mimes.ContainsKey($ext)) { $mimes[$ext] } else { 'application/octet-stream' }
            $body = [System.IO.File]::ReadAllBytes($filePath)
            $hdr  = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
            $hb   = [System.Text.Encoding]::ASCII.GetBytes($hdr)
            $stream.Write($hb,   0, $hb.Length)
            $stream.Write($body, 0, $body.Length)
            $stream.Flush()
        } else {
            $body = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $hdr  = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
            $hb   = [System.Text.Encoding]::ASCII.GetBytes($hdr)
            $stream.Write($hb,   0, $hb.Length)
            $stream.Write($body, 0, $body.Length)
            $stream.Flush()
        }
    } catch {
        Write-Host "ERR: $_"
    } finally {
        if ($client) { $client.Close() }
    }
}
