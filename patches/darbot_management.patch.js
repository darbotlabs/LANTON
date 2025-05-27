/**
 * LANton integration patch for darbot_management.html
 * 
 * Replaces manual bitnetApiPortInput default with call to LanHub API
 * To apply patch, run:
 * pwsh -Command "(Get-Content -Path darbot_management.html) | ForEach-Object { $_ -replace '(const bitnetApiPortInput = document\.getElementById\(''bitnetApiPortInput''\);)', '$1`nfetch(''/ports'').then(r=>r.json()).then(p=>bitnetApiPortInput.value=p.bitnet);' } | Set-Content -Path darbot_management.html"
 */

// Original code snippet:
// const bitnetApiPortInput = document.getElementById('bitnetApiPortInput');

// New code to be injected:
// const bitnetApiPortInput = document.getElementById('bitnetApiPortInput');
// fetch('/ports').then(r=>r.json()).then(p=>bitnetApiPortInput.value=p.bitnet);
