function conn = connectToSupabase()
    % 1. Βρίσκουμε τον φάκελο που είναι ΑΥΤΟ το script
    [currentPath, ~, ~] = fileparts(mfilename('fullpath'));
    
    % 2. Ψάχνουμε για ΟΠΟΙΟΔΗΠΟΤΕ αρχείο ξεκινάει με 'postgresql' και είναι .jar
    % Έτσι δεν μας νοιάζει αν λέγεται 42.7.2 ή 42.7.5 ή .jar.jar
    jarFiles = dir(fullfile(currentPath, 'postgresql*.jar'));
    
    if isempty(jarFiles)
        error('❌ ΔΕΝ ΒΡΕΘΗΚΕ ΚΑΝΕΝΑ ΑΡΧΕΙΟ JAR!\nΦάκελος: %s\nΒεβαιώσου ότι το αρχείο είναι εκεί.', currentPath);
    else
        % Παίρνουμε το όνομα του πρώτου αρχείου που βρήκαμε
        jarFileName = jarFiles(1).name;
        driverPath = fullfile(currentPath, jarFileName);
        fprintf('🔎 Βρέθηκε ο driver: %s\n', jarFileName);
    end

    % 3. Φόρτωση στο Java Path
    if ~any(contains(javaclasspath, jarFileName))
        javaaddpath(driverPath);
        fprintf('📦 Ο driver φορτώθηκε επιτυχώς.\n');
    end

    % 4. Στοιχεία Σύνδεσης
    host = 'aws-1-eu-north-1.pooler.supabase.com'; 
    port = '5432';
    dbname = 'postgres';
    user = 'postgres.xsqhjphewefeluyywiog';
    pass = 'kavafesrobex26!'; 
    
    url = sprintf('jdbc:postgresql://%s:%s/%s', host, port, dbname);
    
    persistent existingConn;
    
    % 5. Σύνδεση
    if isempty(existingConn) || ~isopen(existingConn)
        try
            existingConn = database(dbname, user, pass, 'org.postgresql.Driver', url);
            if isopen(existingConn)
                fprintf('✅ Η ΣΥΝΔΕΣΗ ΕΠΙΤΕΥΧΘΗ!\n');
            else
                error('Αποτυχία: %s', existingConn.Message);
            end
        catch ME
            fprintf('⚠️ Σφάλμα Σύνδεσης: %s\n', ME.message);
            existingConn = [];
        end
    end
    conn = existingConn;
end