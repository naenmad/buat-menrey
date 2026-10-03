@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM KONFIGURASI ENVIRONMENT & JVM
REM ============================================================
set "JMETER_HOME=C:\apache-jmeter-5.6.3"
set "TEST_PLAN=%~dp0[CLI] PT_SMI_Perencanaan_dan_Permintaan_Pengadaan.jmx"
set "RESULT_ROOT=%~dp0results"

REM Optimalisasi Memory JVM (2GB Heap agar stabil saat load tinggi)
set "JVM_ARGS=-Xms2g -Xmx2g -XX:+UseG1GC"

REM Cek dependensi JMeter & File Test Plan
if not exist "%JMETER_HOME%\bin\jmeter.bat" (
    echo [ERROR] jmeter.bat tidak ditemukan di "%JMETER_HOME%\bin"
    pause
    exit /b 1
)

if not exist "%TEST_PLAN%" (
    echo [ERROR] Test plan tidak ditemukan: "%TEST_PLAN%"
    pause
    exit /b 1
)

if not exist "%RESULT_ROOT%" mkdir "%RESULT_ROOT%"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "SESSION_ID=%%i"

echo ============================================================
echo   PROGRESSIVE PERFORMANCE TEST - JMETER RUNNER
echo ============================================================
echo Test Plan   : %TEST_PLAN%
echo Sesi Uji    : %SESSION_ID%
echo Alokasi JVM : 2GB Heap (G1GC)
echo ============================================================
echo.

:INPUT_USERS
set "USER_LIST="
echo Masukkan daftar target user untuk tiap tahapan (pisahkan spasi/koma):
echo Contoh: 10 20 30 50 (atau satu angka saja misal: 25)
set /p "USER_LIST=>> Target Users: "

if "%USER_LIST%"=="" (
    echo.
    echo [!] Input tidak boleh kosong. Silakan masukkan minimal satu angka.
    echo.
    goto INPUT_USERS
)

set "COOLDOWN=30"
set /p "COOLDOWN=>> Jeda istirahat (cooldown) antar tahap dalam detik [Default: 30]: "

set "THINK_TIME=1000"
set /p "THINK_TIME=>> Think time antar request dalam milidetik [Default: 1000ms]: "

REM Hitung total tahapan
set /a TOTAL_STAGES=0
for %%u in (%USER_LIST%) do (
    set /a TOTAL_STAGES+=1
)

echo.
echo ============================================================
echo RENCANA PENGUJIAN:
echo - Total Tahap     : %TOTAL_STAGES% tahap (%USER_LIST%)
echo - Think Time       : %THINK_TIME% ms
echo - Cooldown         : %COOLDOWN% detik per tahap
echo - Rasio Ramp-up    : Otomatis 1 detik / user
echo ============================================================
echo Tekan tombol apa saja untuk mulai pengujian...
pause >nul

REM Inisialisasi Summary HTML Dashboard
set "SUMMARY_FILE=%RESULT_ROOT%\summary_%SESSION_ID%.html"
(
    echo ^<!DOCTYPE html^>
    echo ^<html lang="id"^>
    echo ^<head^>
    echo ^<meta charset="UTF-8"^>
    echo ^<title^>Ringkasan Progressive Test - %SESSION_ID%^</title^>
    echo ^<style^>
    echo   body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #f8fafc; margin: 0; padding: 40px 20px; }
    echo   .container { max-width: 900px; margin: 0 auto; background: #1e293b; border-radius: 12px; padding: 32px; box-shadow: 0 10px 25px rgba(0,0,0,0.4); }
    echo   h1 { margin-top: 0; font-size: 24px; color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 16px; }
    echo   .meta { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin: 20px 0; background: #0f172a; padding: 16px; border-radius: 8px; font-size: 14px; }
    echo   .meta div span { color: #94a3b8; display: block; font-size: 12px; margin-bottom: 4px; }
    echo   table { width: 100%; border-collapse: collapse; margin-top: 24px; }
    echo   th { background: #334155; color: #cbd5e1; text-align: left; padding: 12px; font-size: 13px; text-transform: uppercase; }
    echo   td { padding: 14px 12px; border-bottom: 1px solid #334155; font-size: 14px; }
    echo   tr:hover { background: #28364e; }
    echo   .badge { padding: 4px 10px; border-radius: 9999px; font-size: 12px; font-weight: 600; display: inline-block; }
    echo   .badge-success { background: #065f46; color: #34d399; }
    echo   .badge-danger { background: #7f1d1d; color: #f87171; }
    echo   .btn { display: inline-block; background: #0284c7; color: #fff; text-decoration: none; padding: 6px 14px; border-radius: 6px; font-weight: 500; font-size: 13px; transition: background 0.2s; }
    echo   .btn:hover { background: #0369a1; }
    echo ^</style^>
    echo ^</head^>
    echo ^<body^>
    echo ^<div class="container"^>
    echo   ^<h1^>Ringkasan Progressive Performance Test^</h1^>
    echo   ^<div class="meta"^>
    echo     ^<div^>^<span^>WAKTU SESI^</span^>%SESSION_ID%^</div^>
    echo     ^<div^>^<span^>TOTAL TAHAPAN^</span^>%TOTAL_STAGES% Tahap^</div^>
    echo     ^<div^>^<span^>THINK TIME^</span^>%THINK_TIME% ms^</div^>
    echo     ^<div^>^<span^>COOLDOWN^</span^>%COOLDOWN% detik^</div^>
    echo   ^</div^>
    echo   ^<table^>
    echo     ^<thead^>
    echo       ^<tr^>
    echo         ^<th^>Tahap^</th^>
    echo         ^<th^>Jumlah Users^</th^>
    echo         ^<th^>Ramp-up^</th^>
    echo         ^<th^>Status^</th^>
    echo         ^<th^>Log JMeter^</th^>
    echo         ^<th^>Laporan HTML^</th^>
    echo       ^</tr^>
    echo     ^</thead^>
    echo     ^<tbody^>
) > "%SUMMARY_FILE%"

set /a CURRENT_STAGE=0

for %%U in (%USER_LIST%) do (
    set /a CURRENT_STAGE+=1
    set "THREADS=%%U"
    set "RAMPUP=%%U"

    for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAGE_TIME=%%t"

    echo.
    echo ============================================================
    echo [Tahap !CURRENT_STAGE!/!TOTAL_STAGES!] Menjalankan !THREADS! Users (Ramp-up: !RAMPUP!s)...
    echo ============================================================

    set "STAGE_NAME=stage!CURRENT_STAGE!_!THREADS!users_!STAGE_TIME!"
    set "JTL_FILE=%RESULT_ROOT%\test_!STAGE_NAME!.jtl"
    set "REPORT_DIR=%RESULT_ROOT%\report_!STAGE_NAME!"
    set "STAGE_LOG=%RESULT_ROOT%\jmeter_!STAGE_NAME!.log"

    call "%JMETER_HOME%\bin\jmeter.bat" -n -t "%TEST_PLAN%" -j "!STAGE_LOG!" -Jthreads=!THREADS! -Jrampup=!RAMPUP! -Jloops=1 -JthinkTime=%THINK_TIME% -l "!JTL_FILE!" -e -o "!REPORT_DIR!"

    if errorlevel 1 (
        echo.
        echo [ERROR] Tahap !CURRENT_STAGE! (!THREADS! users) gagal dijalankan.
        (
            echo       ^<tr^>
            echo         ^<td^>Tahap !CURRENT_STAGE!^</td^>
            echo         ^<td^>^<strong^>!THREADS! Users^</strong^>^</td^>
            echo         ^<td^>!RAMPUP!s^</td^>
            echo         ^<td^>^<span class="badge badge-danger"^>Gagal^</span^>^</td^>
            echo         ^<td^>^<a href="jmeter_!STAGE_NAME!.log" target="_blank"^>Log^</a^>^</td^>
            echo         ^<td^>-^</td^>
            echo       ^</tr^>
        ) >> "%SUMMARY_FILE%"
        pause
        exit /b 1
    ) else (
        echo.
        echo [SUKSES] Tahap !CURRENT_STAGE! (!THREADS! users) selesai.
        echo Report : !REPORT_DIR!\index.html
        echo Log    : !STAGE_LOG!
        (
            echo       ^<tr^>
            echo         ^<td^>Tahap !CURRENT_STAGE!^</td^>
            echo         ^<td^>^<strong^>!THREADS! Users^</strong^>^</td^>
            echo         ^<td^>!RAMPUP!s^</td^>
            echo         ^<td^>^<span class="badge badge-success"^>Berhasil^</span^>^</td^>
            echo         ^<td^>^<a href="jmeter_!STAGE_NAME!.log" target="_blank"^>Lihat Log^</a^>^</td^>
            echo         ^<td^>^<a class="btn" href="report_!STAGE_NAME!\index.html" target="_blank"^>Buka Dashboard^</a^>^</td^>
            echo       ^</tr^>
        ) >> "%SUMMARY_FILE%"
    )

    if !CURRENT_STAGE! LSS !TOTAL_STAGES! (
        echo.
        echo Istirahat cooldown !COOLDOWN! detik sebelum tahap berikutnya...
        echo (Tekan tombol apa saja jika ingin langsung lanjut tanpa menunggu)
        timeout /t !COOLDOWN!
    )
)

REM Selesaikan HTML Dashboard
(
    echo     ^</tbody^>
    echo   ^</table^>
    echo ^</div^>
    echo ^</body^>
    echo ^</html^>
) >> "%SUMMARY_FILE%"

REM Notifikasi Bunyi (Alert Beep)
powershell -NoProfile -Command "[console]::beep(900, 200); Start-Sleep -Milliseconds 80; [console]::beep(1200, 400)" >nul 2>&1

echo.
echo ============================================================
echo SEMUA %TOTAL_STAGES% TAHAP PENGUJIAN SELESAI DENGAN SUKSES!
echo Master Summary Dashboard: %SUMMARY_FILE%
echo ============================================================
echo.

set "OPEN_DASHBOARD=Y"
set /p "OPEN_DASHBOARD=Buka Master Summary Dashboard di browser? (Y/T) [Default: Y]: "
if /i "!OPEN_DASHBOARD!"=="Y" (
    start "" "%SUMMARY_FILE%"
)

set "OPEN_FOLDER=T"
set /p "OPEN_FOLDER=Buka folder hasil pengujian di Explorer? (Y/T) [Default: T]: "
if /i "!OPEN_FOLDER!"=="Y" (
    explorer "%RESULT_ROOT%"
)

echo.
pause
endlocal