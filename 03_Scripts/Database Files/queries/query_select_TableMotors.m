% 1. Διάβασμα των δεδομένων (Τώρα που η SQL τα έφτιαξε)
sqlquery = 'SELECT * FROM "Maxon_EC_Flat_Motors"'; 
data = fetch(conn, sqlquery);

% 2. Έλεγχος τύπου δεδομένων
if ~isempty(data)
    fprintf('✅ Τα δεδομένα φορτώθηκαν σωστά!\n');
    
    % Έλεγχος αν η στήλη Nom_I_A_ είναι πλέον αριθμητική
    if isnumeric(data.Nom_I_A_)
        fprintf('📊 Οι στήλες αναγνωρίστηκαν ως αριθμοί (Double).\n');
    else
        fprintf('⚠️ Κάτι πήγε στραβά με το SQL cast, οι στήλες είναι ακόμα Cell.\n');
    end
    
    % 3. Δημιουργία Γραφήματος: Ροπή vs Ρεύμα
    % Αυτή η σχέση είναι πάντα γραμμική στους DC κινητήρες
    figure('Color', 'w');
    plot(data.Nom_I_A_, data.Nom_Torque_mNm_, 'ro', 'MarkerFaceColor', 'r');
    grid on;
    xlabel('Nominal Current (A)');
    ylabel('Nominal Torque (mNm)');
    title('Maxon Motors: Torque vs Current Characteristic');
    
    % Προαιρετικά: Πρόσθεσε μια γραμμή τάσης (Trendline)
    hold on;
    p = polyfit(data.Nom_I_A_, data.Nom_Torque_mNm_, 1);
    f = polyval(p, data.Nom_I_A_);
    plot(data.Nom_I_A_, f, 'b--');
    legend('Data Points', 'Torque Constant (Kt)', 'Location', 'NorthWest');
else
    disp('Ο πίνακας είναι άδειος.');
end