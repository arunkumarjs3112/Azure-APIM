param ($BaseUri)

$ErrorActionPreference = "Stop"
Write-Host "URL: $BaseUri"
function Get-TestMessage {
    param ($esid, $duns)

    $message = @'
    <?xml version='1.0' encoding='UTF-8'?>
    <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
                   soap:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"
                   xmlns:cus="urn:ws.solvedirect.com/webservices/custom">
        <soap:Body>
            <cus:putCall>
                <CallData>
                    <action>CREATE</action>
                    <callType>INCIDENT</callType>
                    <record>
                        <sys_id>c9b41940cbb35519d9ed73f873c38d87</sys_id>
                        <client_duns_number>{{DUNS}}</client_duns_number>
                        <vendor_duns_number/>
                        <customer_esid>{{ESID}}</customer_esid>
                        <client_external_number/>
                        <number>ICM12345</number>
                    </record>
                </CallData>
            </cus:putCall>
        </soap:Body>
    </soap:Envelope>
'@

    $message = $message -replace "{{ESID}}", $esid
    $message = $message -replace "{{DUNS}}", $duns
    return $message.Trim()
}

function Invoke-Test {
    param ($uri, $esid, $duns, $expectedStatus)

    Write-Host "Test: $uri"

    $response = try {
        $body = Get-TestMessage -esid $esid -duns $duns
        (Invoke-WebRequest -Method "POST" -Uri $uri -Body $body).BaseResponse
    } catch {
        $_.Exception.Response
    }

    $actualStatus = [int]$response.StatusCode

    if ($expectedStatus -ne $actualStatus) {
        throw "Test failed: Expected Status: $expectedStatus; Actual Status: $actualStatus"
    }

    Write-Host "Smoke test passed" -ForegroundColor Green
}

Invoke-Test -uri "$baseUri/foo/bar" -esid "" -duns "" -expectedStatus 404
Invoke-Test -uri "$baseUri/i2/foo/bar" -esid "" -duns "" -expectedStatus 404

Invoke-Test -uri "$baseUri/ldc-router" -esid "SPG-12345" -duns "" -expectedStatus 401
Invoke-Test -uri "$baseUri/ldc-router" -esid "" -duns "123456789" -expectedStatus 401
Invoke-Test -uri "$baseUri/ldc-router" -esid "" -duns "" -expectedStatus 400

Invoke-Test -uri "$baseUri/edc-router" -esid "SPG-12345" -duns "" -expectedStatus 401
Invoke-Test -uri "$baseUri/edc-router" -esid "" -duns "123456789" -expectedStatus 401
Invoke-Test -uri "$baseUri/edc-router" -esid "" -duns "" -expectedStatus 400

Invoke-Test -uri "$baseUri/oauth/AM/Brookfield_Tasks/Brookfield_Producer_API" -esid "" -duns "" -expectedStatus 401
