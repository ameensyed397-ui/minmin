Write-Host "Creating Python virtual environment..."
python -m venv .venv

Write-Host "Activating environment and installing backend dependencies..."
& .\.venv\Scripts\python.exe -m pip install --upgrade pip
& .\.venv\Scripts\python.exe -m pip install -r requirements.txt

Write-Host "Preparing Flutter packages..."
Push-Location mobile_app
flutter pub get
Pop-Location

Write-Host "Pocket Claude setup complete."
