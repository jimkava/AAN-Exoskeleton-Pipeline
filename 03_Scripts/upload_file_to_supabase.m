function fileUrl = upload_file_to_supabase(localFilePath, remoteFileName)
    % VERSION 5.0: FIXED CASE SENSITIVITY (Reports)
    
    % --- ΡΥΘΜΙΣΕΙΣ ---
    supabaseUrl = 'https://xsqhjphewefeluyywiog.supabase.co'; 
    apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzcWhqcGhld2VmZWx1eXl3aW9nIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2OTIxOTcwMiwiZXhwIjoyMDg0Nzk1NzAyfQ.J_WfhLgy3Ovc5dWBp-zBjNIA0q-8wRJ_3b7CFaM1Reg'; % <--- Βάλε το κλειδί σου
    bucketName = 'Reports'; % <--- ΕΔΩ Η ΑΛΛΑΓΗ: Κεφαλαίο R
    % -----------------

    import matlab.net.http.*
    import matlab.net.http.field.*

    if ~isfile(localFilePath)
        fileUrl = ''; return;
    end
    
    % Διασφαλίζουμε char vectors για τη σύνθεση του URL
    targetUrl = [char(supabaseUrl), '/storage/v1/object/', char(bucketName), '/', char(remoteFileName)];
    
    key = char(apiKey);
    
    % Κατασκευή Header με χρήση λίστας για αποφυγή σφαλμάτων διαστάσεων
    headers = HeaderField.empty;
    headers(1) = HeaderField('apikey', key);
    headers(2) = HeaderField('Authorization', ['Bearer ' key]);
    headers(3) = HeaderField('Content-Type', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    provider = io.FileProvider(localFilePath);
    options = HTTPOptions('VerifyServerName', false, 'ConnectTimeout', 20);
    request = RequestMessage('POST', headers, provider);
    
    try
        fprintf('☁️ Uploading to Reports Bucket: %s... ', char(remoteFileName));
        response = send(request, targetUrl, options);
        
        if response.StatusCode == StatusCode.OK
            % Το Link για το public access
            fileUrl = [char(supabaseUrl), '/storage/v1/object/public/', char(bucketName), '/', char(remoteFileName)];
            fprintf('✅ ΕΠΙΤΥΧΙΑ!\n');
        else
            fprintf('❌ ΑΠΟΤΥΧΙΑ (Status: %d)\n', double(response.StatusCode));
            % Εμφάνιση μηνύματος σφάλματος από το Supabase αν υπάρχει
            if ~isempty(response.Body)
                disp(response.Body.Data);
            end
            fileUrl = '';
        end
    catch ME
        fprintf('❌ ERROR: %s\n', ME.message);
        fileUrl = '';
    end
end