param (
    [switch]$BuildWeb = $false
)

$ErrorActionPreference = "Stop"
$monorepo = $PSScriptRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   DCW-SETIF: Unified Monorepo Deployment Engine" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Optional Web Build
if ($BuildWeb) {
    Write-Host "`n[1/5] Building Flutter Web Release..." -ForegroundColor White
    Set-Location "$monorepo\tracker"
    flutter build web --release --no-tree-shake-icons
    Write-Host "      Copying web build to backend/public..." -ForegroundColor Gray
    robocopy "$monorepo\tracker\build\web" "$monorepo\backend\public" /E /NFL /NDL /NJH /NJS | Out-Null
    Write-Host "      Web build copied to backend/public successfully." -ForegroundColor Green
} else {
    Write-Host "`n[1/5] Skipping web build (-BuildWeb flag not specified)." -ForegroundColor Gray
}

# 2. Commit & Push Monorepo
Write-Host "`n[2/5] Committing & Pushing Unified Monorepo..." -ForegroundColor White
Set-Location "$monorepo"
git add .
$status = git status --porcelain
if ($status) {
    git commit -m "chore(sync): automated monorepo sync"
}
git push origin main
Write-Host "      Monorepo pushed to github.com/matique2026ai-ux/DCW-SETIF." -ForegroundColor Green

# 3. Deploy Backend to Render Repo
Write-Host "`n[3/5] Deploying Backend to DCW-SETIF-BACKEND..." -ForegroundColor White
$existingB = git branch --list __deploy_backend
if ($existingB) { git branch -D __deploy_backend | Out-Null }
git subtree split --prefix=backend -b __deploy_backend
git push -f https://github.com/matique2026ai-ux/DCW-SETIF-BACKEND.git __deploy_backend:main
git branch -D __deploy_backend | Out-Null
curl.exe -s -X POST "https://api.render.com/deploy/srv-daiqf167bikc739mt7lg?key=B2bktUL4jYM" | Out-Null
Write-Host "      Backend deployed and Render API hook triggered." -ForegroundColor Green

# 4. Deploy Tracker to Render Repo
Write-Host "`n[4/5] Deploying Tracker to DCW-SETIF-TRACKER..." -ForegroundColor White
$existingT = git branch --list __deploy_tracker
if ($existingT) { git branch -D __deploy_tracker | Out-Null }
git subtree split --prefix=tracker -b __deploy_tracker
git push -f https://github.com/matique2026ai-ux/DCW-SETIF-TRACKER.git __deploy_tracker:main
git branch -D __deploy_tracker | Out-Null
curl.exe -s -X POST "https://api.render.com/deploy/srv-dairbhdg1s2s738fig10?key=GLgWofYjMBE" | Out-Null
Write-Host "      Tracker deployed and Render Web hook triggered." -ForegroundColor Green

# 5. Health Check
Write-Host "`n[5/5] Checking Live Health..." -ForegroundColor White
Start-Sleep -Seconds 3
$health = curl.exe -s "https://drh-setif-api.onrender.com/api/health"
Write-Host "      Live API: $health" -ForegroundColor Green
$webHeader = curl.exe -s -I "https://dcw-setif-tracker.onrender.com" | Select-String "HTTP/"
Write-Host "      Live Web App: $webHeader" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   SUCCESS: Monorepo completely deployed and live!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
