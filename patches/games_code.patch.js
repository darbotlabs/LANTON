/**
 * LANton integration patch for Games/code.html
 * 
 * Adds LANHub /ports to endpoint discovery list
 * To apply patch, run:
 * pwsh -Command "(Get-Content -Path Games/code.html) | ForEach-Object { $_ -replace '(const endpoints = \[)', '$1`n        { name: \"LANHub Ports\", url: \"http://localhost:7071/ports\" },' } | Set-Content -Path Games/code.html"
 */

// Original code snippet:
// const endpoints = [

// New code to be injected:
// const endpoints = [
//     { name: "LANHub Ports", url: "http://localhost:7071/ports" },
