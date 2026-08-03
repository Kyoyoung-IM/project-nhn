param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8060,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
$webRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'web'))
$indexPath = Join-Path $webRoot 'index.html'

if (-not (Test-Path -LiteralPath $indexPath -PathType Leaf)) {
    throw "Web build not found: $indexPath"
}

$mimeTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.js'   = 'text/javascript; charset=utf-8'
    '.wasm' = 'application/wasm'
    '.pck'  = 'application/octet-stream'
    '.png'  = 'image/png'
    '.ico'  = 'image/x-icon'
    '.json' = 'application/json; charset=utf-8'
}

$listener = [System.Net.Sockets.TcpListener]::new(
    [System.Net.IPAddress]::Loopback,
    $Port
)
$listener.Start()
$url = "http://127.0.0.1:$Port/"

Write-Host ''
Write-Host "Project NHN Web build: $url" -ForegroundColor Cyan
Write-Host 'Stop the server with Ctrl+C. Do not close the browser tab by opening index.html directly.'
Write-Host ''

if (-not $NoBrowser) {
    Start-Process $url
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new(
                $stream,
                [System.Text.Encoding]::ASCII,
                $false,
                1024,
                $true
            )

            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) {
                continue
            }

            while ($true) {
                $headerLine = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($headerLine)) {
                    break
                }
            }

            $requestParts = $requestLine.Split(' ')
            $method = $requestParts[0]
            $rawTarget = if ($requestParts.Length -ge 2) { $requestParts[1] } else { '/' }
            $statusCode = 200
            $statusText = 'OK'
            $body = [byte[]]::new(0)
            $contentType = 'text/plain; charset=utf-8'

            if ($method -ne 'GET' -and $method -ne 'HEAD') {
                $statusCode = 405
                $statusText = 'Method Not Allowed'
                $body = [System.Text.Encoding]::UTF8.GetBytes('Method Not Allowed')
            }
            else {
                $requestUri = [System.Uri]::new("http://127.0.0.1$rawTarget")
                $relativePath = [System.Uri]::UnescapeDataString(
                    $requestUri.AbsolutePath.TrimStart('/')
                )
                if ([string]::IsNullOrWhiteSpace($relativePath)) {
                    $relativePath = 'index.html'
                }

                $filePath = [System.IO.Path]::GetFullPath((Join-Path $webRoot $relativePath))
                $rootPrefix = $webRoot.TrimEnd('\') + '\'
                $insideWebRoot = $filePath.StartsWith(
                    $rootPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                )

                if (-not $insideWebRoot) {
                    $statusCode = 403
                    $statusText = 'Forbidden'
                    $body = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
                }
                elseif (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                    $statusCode = 404
                    $statusText = 'Not Found'
                    $body = [System.Text.Encoding]::UTF8.GetBytes('Not Found')
                }
                else {
                    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                    if ($mimeTypes.ContainsKey($extension)) {
                        $contentType = $mimeTypes[$extension]
                    }
                    else {
                        $contentType = 'application/octet-stream'
                    }
                    $body = [System.IO.File]::ReadAllBytes($filePath)
                }
            }

            $responseHeaders = @(
                "HTTP/1.1 $statusCode $statusText"
                "Content-Type: $contentType"
                "Content-Length: $($body.Length)"
                'Cache-Control: no-cache'
                'Cross-Origin-Opener-Policy: same-origin'
                'Cross-Origin-Embedder-Policy: require-corp'
                'Cross-Origin-Resource-Policy: same-origin'
                'Connection: close'
                ''
                ''
            ) -join "`r`n"

            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($responseHeaders)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            if ($method -ne 'HEAD' -and $body.Length -gt 0) {
                $stream.Write($body, 0, $body.Length)
            }
            $stream.Flush()
        }
        catch {
            Write-Warning $_.Exception.Message
        }
        finally {
            $client.Dispose()
        }
    }
}
finally {
    $listener.Stop()
}
