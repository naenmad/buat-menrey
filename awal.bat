@echo off
setlocal EnableExtensions

set "JMETER_HOME=C:\apache-jmeter-5.6.3"
set "TEST_PLAN=%~dp0[CLI] PT_SMI_Perencanaan_dan_Permintaan_Pengadaan.jmx"
set "RESULT_ROOT=%~dp0results"

for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "timestamp=%%i"

if not exist "%JMETER_HOME%\bin\jmeter.bat" (
    echo ERROR: jmeter.bat tidak ditemukan di "%JMETER_HOME%\bin"
    pause
    exit /b 1
)

if not exist "%TEST_PLAN%" (
    echo ERROR: Test plan tidak ditemukan: "%TEST_PLAN%"
    pause
    exit /b 1
)

if not exist "%RESULT_ROOT%" mkdir "%RESULT_ROOT%"

echo ============================================================
echo PERFORMANCE TEST PT SMI - 18 DAN 30 USERS
echo Test plan : %TEST_PLAN%
echo Timestamp : %timestamp%
echo ============================================================
echo.

REM TEST 1 - 18 USERS, 1 user mulai setiap 1 detik
echo [TEST 1/2] Running 18 users, ramp-up 18 seconds...
call "%JMETER_HOME%\bin\jmeter.bat" -n -t "%TEST_PLAN%" -Jthreads=18 -Jrampup=18 -Jloops=1 -JthinkTime=1000 -l "%RESULT_ROOT%\test_18users_%timestamp%.jtl" -e -o "%RESULT_ROOT%\report_18users_%timestamp%"

if errorlevel 1 (
    echo ERROR: Test 18 users gagal dijalankan.
    pause
    exit /b 1
)

echo Test 18 users completed.
echo Report: %RESULT_ROOT%\report_18users_%timestamp%\index.html
echo.

REM Beri jeda sebelum skenario berikutnya
echo Waiting 30 seconds before the next test...
timeout /t 30 /nobreak >nul

REM TEST 2 - 30 USERS, 1 user mulai setiap 1 detik
echo [TEST 2/2] Running 30 users, ramp-up 30 seconds...
call "%JMETER_HOME%\bin\jmeter.bat" -n -t "%TEST_PLAN%" -Jthreads=30 -Jrampup=30 -Jloops=1 -JthinkTime=1000 -l "%RESULT_ROOT%\test_30users_%timestamp%.jtl" -e -o "%RESULT_ROOT%\report_30users_%timestamp%"

if errorlevel 1 (
    echo ERROR: Test 30 users gagal dijalankan.
    pause
    exit /b 1
)

echo Test 30 users completed.
echo Report: %RESULT_ROOT%\report_30users_%timestamp%\index.html
echo.

echo ============================================================
echo ALL 2 TESTS COMPLETED
echo Results location: %RESULT_ROOT%
echo 18 users report: %RESULT_ROOT%\report_18users_%timestamp%\index.html
echo 30 users report: %RESULT_ROOT%\report_30users_%timestamp%\index.html
echo Timestamp: %timestamp%
echo ============================================================
echo.
pause

endlocal