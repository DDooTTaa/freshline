@echo off
REM Flutter Web 실행 스크립트 (HTML 렌더러 사용 - 셰이더 컴파일 오류 우회)
REM 이 스크립트는 HTML 렌더러를 사용하여 셰이더 컴파일 오류를 우회합니다.

echo Flutter Web 앱을 HTML 렌더러로 실행합니다...
echo 이 방법은 셰이더 컴파일 오류를 우회합니다.

flutter run -d chrome --web-renderer html

pause
