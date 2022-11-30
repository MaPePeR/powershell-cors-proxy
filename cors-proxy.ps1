param([Parameter(Mandatory=$true)][String[]]$targetUris, [Parameter(Mandatory=$true)][String[]]$allowedOrigins,[int]$port=8080)
Write-Host "powershell-cors-proxy  Copyright (C) 2022  MaPePeR, Simon Mourier"
Write-Host "This program comes with ABSOLUTELY NO WARRANTY"
Write-Host "This is free software, and you are welcome to redistribute it under certain conditions."
Write-Host "See the LICENSE file at https://github.com/MaPePeR/powershell-cors-proxy/blob/main/LICENSE"

$assemblies = ("System.Net.Http")
Add-Type -ReferencedAssemblies $assemblies @"
using System;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

public class CorsProxy {
    public static void main(string[] targetUris, string[] allowedOrigins, int port) {
        var proxy = new CorsProxy(
            new string[] {"http://localhost:" + port + "/", "http://127.0.0.1:" + port + "/"},
            allowedOrigins,
            targetUris
        );
        try {
            proxy.Start();
            Console.WriteLine("Press ESC to stop");
            while (Console.ReadKey().Key != ConsoleKey.Escape) {
            }
        } catch (Exception e) {
            Console.WriteLine("Caught Exception: ");
            Console.WriteLine(e.ToString());
        } finally {
            proxy.Stop();
        }
    }

    private readonly HttpListener listener = new HttpListener();
    private readonly HttpClient client = new HttpClient();

    private readonly string[] targetUris;
    private readonly string[] allowedOrigins;


    public CorsProxy(string[] prefixes, string[] allowedOrigins, string[] targetUris) {
        foreach (string s in prefixes) {
            listener.Prefixes.Add(s);
            Console.WriteLine("Listening on " + s);
        }
        foreach (string s in allowedOrigins) {
            Console.WriteLine("Allowed Origin: " + s);
        }
        foreach (string s in targetUris) {
            Console.WriteLine("Allowed target URI: " + s + "...");
        }
        this.targetUris = targetUris;
        this.allowedOrigins = allowedOrigins;
    }

    public void Start() {
        listener.Start();
        QueueListener();
    }

    public void Stop() {
        listener.Stop();
    }

    public void QueueListener() {
        listener.BeginGetContext(new AsyncCallback(ListenerCallback), null);
    }

    private void ListenerCallback(IAsyncResult result) {
        try {
            if (!listener.IsListening) {
                return;
            }
            QueueListener();
            HttpListenerContext context = listener.EndGetContext(result);
            HttpListenerRequest request = context.Request;
            using (HttpListenerResponse response = context.Response) {
                Proxy(request, response).Wait();
            }
        } catch (Exception e) {
            Console.WriteLine("Exception in ListenerCallback");
            Console.WriteLine(e.ToString());
        }
    }

    private HttpRequestMessage CreateProxyRequest(HttpListenerRequest request) {
        var proxyRequest = new HttpRequestMessage(new HttpMethod(request.HttpMethod), request.RawUrl.Substring(1));
        // Copy some headers from Request to Proxy-Request
        foreach (string headerName in request.Headers) {
            var headerValue = request.Headers[headerName];
            if (headerName == "Authorization") {
                proxyRequest.Headers.Add(headerName, headerValue);
            }
        }
        // Copy Request Body
        if (request.HasEntityBody) {
            proxyRequest.Content = new StreamContent(request.InputStream);
            proxyRequest.Content.Headers.Add("Content-Type", request.ContentType);
        }
        return proxyRequest;
    }

    private bool IsValidTargetURI(string targetUri) {
        foreach (string allowed in this.targetUris) {
            if (targetUri.StartsWith(allowed)) {
                return true;
            }
        }
        return false;
    }

    private async Task Proxy(HttpListenerRequest request, HttpListenerResponse response) {
        Console.WriteLine(request.RawUrl);
        var origin = request.Headers["Origin"];
        // Set Access-Control-Allow-Origin Header if Origin is one of the allowed ones
        foreach (string allowedOrigin in this.allowedOrigins) {
            if (origin == allowedOrigin) {
                response.Headers.Add("Access-Control-Allow-Origin", origin);
            }
        }
        // Allow all Headers
        if (request.Headers.Get("Access-Control-Request-Headers") != null) {
            response.Headers.Add("Access-Control-Allow-Headers", request.Headers.Get("Access-Control-Request-Headers"));
        }
        // Allow all Methods
        if (request.Headers.Get("Access-Control-Request-Method") != null) {
            response.Headers.Add("Access-Control-Allow-Method", request.Headers.Get("Access-Control-Request-Method"));
        }
        // Don't proxy OPTIONS requests to target
        if (request.HttpMethod == "OPTIONS") return;

        // Don't proxy requests to / Path
        if (!IsValidTargetURI(request.RawUrl.Substring(1))) {
            response.StatusCode = 400;
            return;
        }

        using (HttpRequestMessage proxyRequest = CreateProxyRequest(request)) {
            using (HttpResponseMessage targetResponse = await client.SendAsync(proxyRequest).ConfigureAwait(false)) {
                response.ProtocolVersion = targetResponse.Version;
                response.StatusCode = (int)targetResponse.StatusCode;
                response.StatusDescription = targetResponse.ReasonPhrase;

                // Copy all Headers from target to our response
                foreach (var header in targetResponse.Headers) {
                    response.Headers.Add(header.Key, string.Join(", ", header.Value));
                }
                foreach (var header in targetResponse.Content.Headers) {
                    if (header.Key == "Content-Length")
                        continue;
                    response.Headers.Add(header.Key, string.Join(", ", header.Value));
                }

                await targetResponse.Content.CopyToAsync(response.OutputStream);
            }
        }
    }
}
"@

try {
    [CorsProxy]::main($targetUris,$allowedOrigins,$port)
} catch {
    Write-Host "Error Occured" -f Red
    $_.Exception
}
