@echo off
chcp 65001 > nul
REM Инсталира OlxDB и OlxDW на локален SQL Server (Windows authentication).
REM Ако ползвате SQL Express: install.bat .\SQLEXPRESS
set SERVER=%1
if "%SERVER%"=="" set SERVER=localhost

for %%f in (sql\01_create_database.sql sql\02_functions.sql sql\03_stored_procedures.sql sql\04_triggers.sql sql\05_views.sql sql\06_seed_data.sql data-warehouse\01_create_dw.sql data-warehouse\02_load_dw.sql) do (
    echo ===== %%f
    sqlcmd -S %SERVER% -E -b -I -f 65001 -i %%f
    if errorlevel 1 (
        echo Грешка при %%f
        exit /b 1
    )
)
echo Готово - базите OlxDB и OlxDW са създадени.
