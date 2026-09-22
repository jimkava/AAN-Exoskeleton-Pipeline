function motorTable = getMotorTable(conn)
    % Έλεγχος αν η σύνδεση είναι ενεργή
    if isempty(conn) || ~isopen(conn)
        error('Η σύνδεση conn δεν είναι έγκυρη ή έχει κλείσει.');
    end
    
    % SQL Query: Τραβάμε τα πάντα από τον πίνακα
    sqlquery = 'SELECT * FROM "Maxon_EC_Flat_Motors"'; 
    
    try
        % Ανάκτηση των δεδομένων σε MATLAB Table
        motorTable = fetch(conn, sqlquery);
        
        % Έλεγχος: Αν οι στήλες είναι Cell (κείμενο) λόγω κομμάτων, τις φτιάχνουμε εδώ
        % (Αν έτρεξες το SQL query στο Supabase, αυτό το κομμάτι θα προσπεραστεί αυτόματα)
        if iscell(motorTable.Nom_I_A_)
             motorTable.Nom_I_A_ = str2double(strrep(motorTable.Nom_I_A_, ',', '.'));
        end
        if iscell(motorTable.Nom_Torque_mNm_)
             motorTable.Nom_Torque_mNm_ = str2double(strrep(motorTable.Nom_Torque_mNm_, ',', '.'));
        end
        
        fprintf('📊 Ο πίνακας φορτώθηκε: %d κινητήρες βρέθηκαν.\n', height(motorTable));
        
    catch ME
        fprintf('⚠️ Σφάλμα κατά την ανάγνωση του πίνακα: %s\n', ME.message);
        motorTable = table(); % Επιστρέφει άδειο πίνακα
    end
end