$port = 8090
$folder = "c:\Users\ASUS 2\Nouveau dossier\DCW-SETIF-TRACKER\build\web"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Prefixes.Add("http://127.0.0.1:$port/")
$listener.Start()
Write-Host "Server running at http://localhost:$port/"

$mimeMap = @{
    ".html" = "text/html; charset=utf-8";
    ".js"   = "application/javascript; charset=utf-8";
    ".mjs"  = "application/javascript; charset=utf-8";
    ".json" = "application/json; charset=utf-8";
    ".css"  = "text/css; charset=utf-8";
    ".png"  = "image/png";
    ".jpg"  = "image/jpeg";
    ".svg"  = "image/svg+xml";
    ".wasm" = "application/wasm";
    ".ttf"  = "font/ttf";
    ".otf"  = "font/otf";
    ".woff" = "font/woff";
    ".woff2"= "font/woff2";
}

while ($listener.IsListening) {
    try {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $rawUrl = $request.Url.AbsolutePath
        if ($rawUrl -eq "/") { $rawUrl = "/index.html" }
        $filePath = Join-Path $folder $rawUrl.TrimStart('/')

        if (-not (Test-Path $filePath -PathType Leaf)) {
            $filePath = Join-Path $folder "index.html"
        }

        $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
        $mime = if ($mimeMap.ContainsKey($ext)) { $mimeMap[$ext] } else { "application/octet-stream" }
        $response.ContentType = $mime
        $response.AddHeader("Access-Control-Allow-Origin", "*")
        $response.AddHeader("Cache-Control", "no-cache, no-store, must-revalidate, max-age=0")
        $response.AddHeader("Pragma", "no-cache")
        $response.AddHeader("Expires", "0")

        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $response.ContentLength64 = $bytes.Length
        $response.OutputStream.Write($bytes, 0, $bytes.Length)
        $response.OutputStream.Close()
    } catch {
        # continue
    }
}
