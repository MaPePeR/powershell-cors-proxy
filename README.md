# powershell-cors-proxy
Simple and inspectable CORS proxy written using C# and Powershell to be "easily" usable on Windows.

# Usage

Download the [`cors-proxy.ps1` file](https://raw.githubusercontent.com/MaPePeR/powershell-cors-proxy/main/cors-proxy.ps1) and make sure to save it with the file extension `.ps1`.

You can right-click the file and select "Run with PowerShell". You will be asked to enter one or more allowed `targetUris` to which the cors requests can be redirected and one or more `allowedOrigins` from which CORS requests are accepted.

![image](https://user-images.githubusercontent.com/527679/204899577-bb8119a1-db78-45dd-a613-6dbc27c7549d.png)


You can then use `http://localhost:8080/https://someapi.example.com/some_cors_disabled_route` to fetch data from a CORS-disabled URL.

An alternative is to press <kbd>Win</kbd> + <kbd>R</kbd> and run `powershell`. Then enter this into the PowerShell Window and replace the placeholders:
```
powershell -executionpolicy bypass -Command "<Path to cors-proxy.ps1>" -targetUris "<Your Target URL>" -allowedOrigins '<Your allowed origin>'
```

# Attribution

This program is heavily inspired by [this StackOverflow Answer](https://stackoverflow.com/a/58039128/2256700) and [Rob--W/cors-anywhere](https://github.com/Rob--W/cors-anywhere).
