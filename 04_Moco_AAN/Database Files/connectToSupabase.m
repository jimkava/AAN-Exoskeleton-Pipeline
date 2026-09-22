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

    % 4. Στοιχεία Σύνδεσης από environment variables
    %    Ορίστε τα πριν τη χρήση (Windows, μία φορά, σε cmd):
    %      setx SUPABASE_HOST "..."
    %      setx SUPABASE_PORT "5432"
    %      setx SUPABASE_DB   "postgres"
    %      setx SUPABASE_USER "..."
    %      setx SUPABASE_PASS "..."
    %    Μετά κλείστε και ξανανοίξτε το MATLAB.
    host   = getenv('SUPABASE_HOST');
    port   = getenv('SUPABASE_PORT');
    dbname = getenv('SUPABASE_DB');
    user   = getenv('SUPABASE_USER');
    pass   = getenv('SUPABASE_PASS');

    if isempty(port),   port   = '5432';     end
    if isempty(dbname), dbname = 'postgres'; end

    missing = {};
    if isempty(host), missing{end+1} = 'SUPABASE_HOST'; end
    if isempty(user), missing{end+1} = 'SUPABASE_USER'; end
    if isempty(pass), missing{end+1} = 'SUPABASE_PASS'; end
    if ~isempty(missing)
        error(['❌ Λείπουν μεταβλητές περιβάλλοντος: %s\n' ...
               'Ορίστε τις με setx και επανεκκινήστε το MATLAB.'], ...
               strjoin(missing, ', '));
    end
    
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
