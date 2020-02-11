

#Trigger che, alla decisione di un utente di usufruire della manutenzione automatica per un dato esemplare,
#basandosi sulle informazioni del sistema riguardanti la sua specie di appartenenza,
#organizza gli interventi per i 5 anni successivi. Scaduti i 10 anni, un event provvede a inviare un'email all'utente interessato in cui
#gli chiede se vuole continuare a usufruire del servizio. Se sì calcola anche i successivi 10 anni.
#La pianificazione degli interventi funziona così:
# - Per ogni anno, vengono previsti gli interventi presenti in 'NecessitaPotatura' e 'EsigenzeConcimazione'
# - A questi viene aggiunto un trattamento preventivo in tutti quei casi in cui c'è una probabilità superiore al 50% di subire attacchi
# - A questo punto vengono inseriti dei interventi aggiuntivi per i primi due anni di vita (in cui la pianta è più delicata) secondo la
#	seguente politica:
#										I anno						II anno	
#	- IndiceManut --> Basso			1 concimazione o					NA	
#									1 trattamento
#
# 	- IndiceManut --> Medio			1 concimazione e				1 concimazione o
#									1 trattamento					1 trattamento
#
#	- IndiceManut --> Alto			2 concimazioni e				1 concimazione e 
#									2 trattamenti					1 trattamento
#
# - Per scegliere se effettuare una concimazione o un trattamento, si ragiona così: per ogni elemento che la pianta necessita, si conta +10;
#   se la probabilità più alta di subire un attacco (dopo quelle che superano il 50%) è superiore al numero trovato prima, si sceglie il trattamento,
#	altrimenti si sceglie la concimazione.
# - Per scegliere il trattamento da effettuare, basta prendere l'agente con più alta probabilità di attacco
# - Per scegliere la concimazione, si sceglie quella con più elementi, fra quelli necessari, disponibile

drop trigger if exists TriggerRichiestaManutenzioneAutomatica;
drop trigger if exists TriggerRichiestaManutenzioneProgrammata;
drop event if exists EventRichiestaConfermaManutenzioneAutomatica;
drop event if exists EventRichiestaConfermaManutenzioneProgrammata;
drop procedure if exists ProcedureCalcoloInterventi;
drop procedure if exists ProcedureAggiungiTrattamento;
drop procedure if exists ProcedureAggiungiConcimazione;

#Ci siamo resi conto che, per poter inviare le richieste di conferma a intervalli regolari, era necessario aggiungere quest'attributo
#alter table Scheda
#	add column DataManutenzioneAutomatica date default null;

delimiter $$

create trigger TriggerRichiestaManutenzioneAutomatica
before update on Scheda
for each row
begin
	#Controlliamo che l'aggiornamento riguardante la scheda abbia riguardato effettivamente un cambio nelle impostazioni
    #riguardanti la manutenzione automatica
	if (new.ManutenzioneAutomatica = true and old.ManutenzioneAutomatica = false) then
		#Controlliamo se abbiamo a che fare con un esemplare giovane
		if (new.DataAcquisto > current_date() - interval 1 year) then
			set @Nuovo = 1;
		else set @Nuovo = 0;
        end if;
        #Aggiorniamo l'attributo DataManutenzioneAutomatica
        set new.DataManutenzioneAutomatica = current_date();
        
        #Controlliamo se nell'esemplare associato alla scheda è già prevista la manutenzione programmata, nel qual caso ci si può anche fermare qua
        set @ManutenzioneProgrammata = (
											select ManutenzioneProgrammata
                                            from Esemplare
                                            where idEsemplare = new.Esemplare
                                            );
        if(@ManutenzioneProgrammata = false)then
			#Chiamiamo la procedure che calcola gli interventi
			set @Tipo = 'Automatico'; #Bisogna distinguere fra interventi automatici e programmati
			call ProcedureCalcoloInterventi(new.Esemplare, @Nuovo, @Tipo);
		end if;
    end if;
end $$


create trigger TriggerRichiestaManutenzioneProgrammata
before update on Esemplare
for each row
begin
	#Controlliamo che l'aggiornamento riguardante l'esemplare abbia riguardato effettivamente un cambio nelle impostazioni
    #riguardanti la manutenzione programmata
	if (new.ManutenzioneProgrammata = true and old.ManutenzioneProgrammata = false) then
		#Controlliamo se abbiamo a che fare con un esemplare giovane
        set @DataAcquisto = (
								select DataAcquisto
                                from Scheda
                                where Esemplare = new.idEsemplare
                                );
		if (@DataAcquisto > current_date() - interval 1 year) then
			set @Nuovo = 1;
		else set @Nuovo = 0;
        end if;
        #Aggiorniamo l'attributo DataManutenzioneProgrammata        
        set new.DataManutenzioneProgrammata = current_date();
        
        #Chiamiamo la procedure che calcola gli interventi
        set @Tipo = 'Programmato';
		call ProcedureCalcoloInterventi(new.idEsemplare, @Nuovo, @Tipo);
    end if;
end $$

#Modifichiamo gli attributi di manutenzione ogni mese nei casi in cui la scelta risale a più di 5 anni fa e inviamo una mail all'utente interessato
create event EventRichiestaConfermaManutenzioneAutomatica
on schedule every 1 month
starts '2016-06-30 00:00:01'
do
begin
	declare Mail varchar(1000);
	declare MailPrimaParte varchar(300);
    declare MailSecondaParte varchar(300);
    declare MailTerzaParte varchar(300);
	declare SchedaSingola int;
    declare AccountSingolo int;
	declare finito int default 0;
    #Recuperiamo le schede interessate
	declare SchedeDaConfermare cursor for
		select idScheda,
			Account
		from Scheda
        where DataManutenzioneAutomatica is not null and
			DataManutenzioneAutomatica > current_date() - interval 5 year;
	
    declare continue handler for
		not found set finito = 1;
        
	#Poniamo gli attributi "ManutenzioneAutomatica" a 0 e "DataManutenzioneAutomatica" a NULL nelle schede interessate
    update Scheda
    set ManutenzioneAutomatica = 0
    where DataManutenzioneAutomatica is not null and
			DataManutenzioneAutomatica > current_date() - interval 5 year;
            
	update Scheda
    set DataManutenzioneAutomatica = current_date()
    where DataManutenzioneAutomatica is not null and
			DataManutenzioneAutomatica > current_date() - interval 5 year;
        
	open SchedeDaConfermare;
    
    set MailPrimaParte = 'Ciao ';
    set MailSecondaParte = ', ci risulta siano passati più di 5 anni da quando hai scelto di avvalerti del nostro sistema di manutenzione automatica per il tuo esemplare di ';
    set MailTerzaParte = '. Per continuare ad usufruirne, aggiorna la scheda relativa. Buon giardinaggio!';
    
    prelievo: loop
		fetch SchedeDaConfermare into SchedaSingola, AccountSingolo;
        if(finito = 1) then
			leave prelievo;
        end if;
        #Recuperiamo le informazioni per costruire la mail di richiesta di conferma
        set @IndirizzoMail = '';
        set @IndirizzoMail = (
								select Email
                                from Account
                                where idAccount = AccountSingolo
                                );
		set @NomeUtente = '';
        set @NomeUtente = (
								select if(Nome is null, Nickname, Nome)
                                from Account
                                where idAccount = AccountSingolo
                                );
		set @Pianta = (
						select NomePianta
                        from Scheda
                        where idScheda = SchedaSingola
                        );
        #Costruiamo la mail
        set Mail = concat(MailPrimaParte, @NomeUtente);
        set Mail = concat(Mail, MailSecondaParte);
        set Mail = concat(Mail, @Pianta);
        set Mail = concat(Mail, MailTerzaParte);
        #Inseriamo il tutto nella mailing list
        insert into MailingList (`IndirizzoMail`, `Mail`) 
			values (@IndirizzoMail, Mail);
    end loop;
end $$


#Modifichiamo gli attributi di manutenzione ogni mese nei casi in cui la scelta risale a più di 5 anni fa e inviamo una mail all'utente interessato
create event EventRichiestaConfermaManutenzioneProgrammata
on schedule every 1 month
starts '2016-06-30 00:00:01'
do
begin
	declare Mail varchar(1000);
	declare MailPrimaParte varchar(300);
    declare MailSecondaParte varchar(300);
    declare MailTerzaParte varchar(300);
	declare EsemplareSingolo int;
    declare AccountSingolo int;
	declare finito int default 0;
    #Recuperiamo le schede interessate
	declare EsemplariDaConfermare cursor for
		select idEsemplare,
			Account
		from Esemplare E inner join Scheda S
			on E.idEsemplare = S.Esemplare
        where DataManutenzioneProgrammata is not null and
			DataManutenzioneProgrammata > current_date() - interval 5 year;
	
    declare continue handler for
		not found set finito = 1;
        
	#Poniamo gli attributi "ManutenzioneProgrammata" a 0 e "DataManutenzioneProgrammata" a NULL per gli esemplari interessati
    update Esemplare
    set ManutenzioneProgrammata = 0
    where DataManutenzioneProgrammata is not null and
			DataManutenzioneProgrammata > current_date() - interval 5 year;
            
	update Esemplare
    set DataManutenzioneProgrammata = current_date()
    where DataManutenzioneProgrammata is not null and
			DataManutenzioneProgrammata > current_date() - interval 5 year;
        
	open EsemplariDaConfermare;
    
    set MailPrimaParte = 'Ciao ';
    set MailSecondaParte = ', ci risulta siano passati più di 5 anni da quando hai scelto di avvalerti del nostro sistema di manutenzione programmata per il tuo esemplare di ';
    set MailTerzaParte = '. Per continuare ad usufruirne, aggiorna la scheda relativa. Buon giardinaggio!';
    
    prelievo: loop
		fetch EsemplariDaConfermare into EsemplareSingolo, AccountSingolo;
        if(finito = 1) then
			leave prelievo;
        end if;
        #Recuperiamo le informazioni per costruire la mail di richiesta di conferma
        set @IndirizzoMail = '';
        set @IndirizzoMail = (
								select Email
                                from Account
                                where idAccount = AccountSingolo
                                );
		set @NomeUtente = '';
        set @NomeUtente = (
								select if(Nome is null, Nickname, Nome)
                                from Account
                                where idAccount = AccountSingolo
                                );
		set @Pianta = (
						select NomePianta
                        from Pianta P inner join Esemplare E
							on P.idPianta = E.Pianta
                        where idEsemplare = EsemplareSingolo
                        );
        #Costruiamo la mail
        set Mail = concat(MailPrimaParte, @NomeUtente);
        set Mail = concat(Mail, MailSecondaParte);
        set Mail = concat(Mail, @Pianta);
        set Mail = concat(Mail, MailTerzaParte);
        #Inseriamo il tutto nella mailing list
        insert into MailingList (`IndirizzoMail`, `Mail`) 
			values (@IndirizzoMail, Mail);
    end loop;
end $$



create procedure ProcedureCalcoloInterventi(in _Esemplare int, in _Nuovo int, in _Tipo varchar(45))
begin
	declare InizioPeriodoSingolo int;
    declare FinePeriodoSingolo int;
    declare PeriodicitaSingola int;
    declare TipoSingolo int;
    declare QuantitaSingola int;
    declare AgenteSingolo int;
	declare finito int default 0;
    
    #Recuperiamo tutte le concimazioni necessarie
    declare PeriodiConcimazioni cursor for
		select TC.InizioPeriodo,
			TC.FinePeriodo,
            TC.Periodicita,
            TC.idConcimazione
		from TipoConcimazione TC inner join EsigenzeConcimazione EC
				on TC.idConcimazione = EC.TipoConcimazione
			inner join Esemplare E
				on EC.Pianta = E.Pianta
		where E.idEsemplare = _Esemplare;
        
	 #Recuperiamo tutte le informazioni relative alle potature necessarie
     declare PeriodiPotature cursor for
		select PP.InizioPeriodo,
			PP.FinePeriodo,
            NP.Quantita,
            PP.TipoPotatura
        from PeriodoPotatura PP natural join NecessitaPotatura NP
			inner join Pianta P 
				on PP.Pianta = P.idPianta
			inner join Esemplare E
				on P.idPianta = E.Pianta
		where E.idEsemplare = _Esemplare;
	
    #Recuperiamo tutte le informazioni necessarie relative ai trattamenti
    declare PeriodiAttacchi cursor for
		select PA.Agente,
			PA.InizioPeriodo,
            PA.FinePeriodo
        from PeriodoAttacchi PA inner join Esemplare E
			on PA.Pianta = E.Pianta
		where E.idEsemplare = _Esemplare and
			PA.Probabilita >= 50;
            
    declare continue handler for
		not found set finito = 1;
	
    
    #-------------------------------------------------------------------------------------------------------------------
    #       GESTIONE DELLE CONCIMAZIONI
    #-------------------------------------------------------------------------------------------------------------------
    
    open PeriodiConcimazioni;
    
    prelievo: loop
		fetch PeriodiConcimazioni into InizioPeriodoSingolo, FinePeriodoSingolo, PeriodicitaSingola, TipoSingolo;
        if (finito = 1) then
			set finito = 0;
			leave prelievo;
        end if;
        #Controlliamo se per quest'anno il periodo è già passato
        if (InizioPeriodoSingolo < month(current_date()))then
			set @MesiDiDistanza = 12 - month(current_date()) + InizioPeriodoSingolo;
		else set @MesiDiDistanza = InizioPeriodoSingolo - month(current_date());
		end if;
        set @NumeroInterventi = (
									select count(*)
                                    from Concimazione
                                    where TipoConcimazione = TipoSingolo
                                    );
        #Inseriamo ora gli interventi cercando di spargerli il più uniformemente possibile
        set @Contatore = 0;
        #Primo loop che controlla l'inserimento degli interventi per i prossimi 5 anni
        inserimentoConcimazioni: loop
			if(@Contatore = 5) then
				leave inserimentoConcimazioni;
            end if;
            set @NumeroConcimazione = 1;
            #Secondo loop che controlla l'inserimento di tutti gli interventi di concimazione singoli
            inserimentoIntervento: loop
				if(@NumeroConcimazione >= @NumeroInterventi + 1) then
					leave inserimentoIntervento;
                end if;
                #Inserimento in intervento
                insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
					#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
                    #A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
					(current_date() + interval (@MesiDiDistanza + @Contatore * 12) month + interval (@NumeroConcimazione * PeriodicitaSingola) week, _Tipo,
						'Concimazione', _Esemplare);
				
                #Recuperiamo l'id dell'intervento appena inserito, necessario per il prossimo inserimento
                set @InterventoInserito = (
											select idIntervento
                                            from Intervento
                                            where Data = current_date() + interval (@MesiDiDistanza + @Contatore * 12) month + interval (@NumeroConcimazione * PeriodicitaSingola) week
												and	Esemplare = _Esemplare and
                                                Tipo = 'Concimazione' and
                                                #Poiché dobbiamo ancora fare la insert in TipoInterventoConcimazione, non esiste ancora un'occorrenza del genere
                                                idIntervento not in
																	(
																		select Intervento
                                                                        from TipoInterventoConcimazione
                                                                        )
											);
				#Inserimento in TipoInterventoConcimazione
                insert into TipoInterventoConcimazione values
					(@InterventoInserito, @NumeroConcimazione, TipoSingolo);
                set @NumeroConcimazione = @NumeroConcimazione + 1;
            end loop;
            set @Contatore = @Contatore + 1;
        end loop;
    end loop;
    
    
    #-------------------------------------------------------------------------------------------------------------------
    #       GESTIONE DELLE POTATURE
    #-------------------------------------------------------------------------------------------------------------------
    
    open PeriodiPotature;
    
    prelievo1: loop
		fetch PeriodiPotature into InizioPeriodoSingolo, FinePeriodoSingolo, QuantitaSingola, TipoSingolo;
        if (finito = 1) then
			set finito = 0;
            leave prelievo1;
        end if;
		
        
		#Individuiamo quanti sono i periodi possibili
        set @NumeroPeriodi = (
								select count(*)
                                from PeriodoPotatura PP natural join Esemplare E
                                where E.idEsemplare = _Esemplare and
									PP.TipoPotatura = TipoSingolo
                                    );
		#Prendiamo la quantità di interventi da effettuare per singolo periodo e la periodicità (che calcoliamo in settimane per semplicità)
        set @NumeroInterventiPeriodo = QuantitaSingola / @NumeroPeriodi;
        set @Periodicita = @NumeroInterventiPeriodo / (4*FinePeriodoSingolo - 4*InizioPeriodoSingolo);
        #Controlliamo se per quest'anno il periodo è già passato
        if (InizioPeriodoSingolo < month(current_date()))then
			set @MesiDiDistanza = 12 - month(current_date()) + InizioPeriodoSingolo;
		else set @MesiDiDistanza = InizioPeriodoSingolo - month(current_date());
		end if;
        #Inseriamo il Numero di interventi da fare in questo periodo in modo il più uniforme possibile, ripetendo per i prossimi 5 anni
        set @Contatore = 0;
        
        inserimentoPotature: loop
			if(@Contatore = 5) then
				leave inserimentoPotature;
            end if;
            set @NumeroIntervento = 1;
            inserimentoSingolo: loop
				if(@NumeroIntervento >= @NumeroInterventiPeriodo +1) then
					leave inserimentoSingolo;
				end if;
                
                #Inserimento in intervento
                insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
					#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
                    #A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
					(current_date() + interval (@MesiDiDistanza + @Contatore * 12) month + interval (@NumeroIntervento * @Periodicita) week, _Tipo,
						'Potatura', _Esemplare);
    
                #Recuperiamo l'id dell'intervento appena inserito, necessario per il prossimo inserimento
                set @InterventoInserito = (
											select idIntervento
                                            from Intervento
                                            where Data = current_date() + interval (@MesiDiDistanza + @Contatore * 12) month  + interval (@NumeroIntervento * @Periodicita) week
												and	Esemplare = _Esemplare and
                                                Tipo = 'Potatura' and
                                                #Poiché dobbiamo ancora fare la insert in TipoInterventoConcimazione, non esiste ancora un'occorrenza del genere
                                                idIntervento not in
																	(
																		select Intervento
                                                                        from TipoInterventoPotatura
                                                                        )
											);
                                            
				#Inserimento in TipoInterventoPotatura
                insert into TipoInterventoPotatura values
					(@InterventoInserito, TipoSingolo);
		
                set @NumeroIntervento = @NumeroIntervento + 1;
            end loop;
            set @Contatore = @Contatore + 1;
		end loop;
	end loop;
    
    
    #-------------------------------------------------------------------------------------------------------------------
    #       GESTIONE DEI TRATTAMENTI
    #-------------------------------------------------------------------------------------------------------------------
    
    open PeriodiAttacchi;
    
    prelievo2: loop
		fetch PeriodiAttacchi into AgenteSingolo, InizioPeriodoSingolo, FinePeriodoSingolo;
        if(finito = 1) then
			set finito = 0;
            leave prelievo2;
        end if;
       
        #Prendiamo la metà del periodo		
		set @MetaPeriodo = (FinePeriodoSingolo - InizioPeriodoSingolo) / 2;
    
		#Controlliamo che il periodo non sia già passato
		if (InizioPeriodoSingolo < month(current_date()))then
			set @MesiDiDistanza = 12 - month(current_date()) + InizioPeriodoSingolo;
		else set @MesiDiDistanza = InizioPeriodoSingolo - month(current_date());
		end if;
    
		
		#Inserimento in intervento
		insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
			#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + Metà Periodo
			(current_date() + interval (@MesiDiDistanza) month + interval (@MetaPeriodo) month, _Tipo,
				'Trattamento', _Esemplare);
		
        
		#Recuperiamo l'id dell'intervento appena inserito
		set @InterventoInserito = (
									select idIntervento
									from Intervento
									where Esemplare = _Esemplare and
										Tipo = 'Trattamento' and
										idIntervento not in (
																select Intervento
																from Trattamento
																)
									);
    
		#Inseriamo in trattamento
		insert into Trattamento (`Intervento`, `Agente`, `Prevenzione`) values
			(@InterventoInserito, AgenteSingolo, 1);
	end loop;
    
    #-------------------------------------------------------------------------------------------------------------------
    #       GESTIONE DEGLI INTERVENTI NEI PRIMI ANNI
    #-------------------------------------------------------------------------------------------------------------------
    
    
    #L'if controlla che si tratta di un esemplare giovane
    if (_Nuovo = 1) then
		#Selezioniamo l'indice di manutenzione della specie dell'esemplare
		set @IndiceManutenzione = (
									select IndiceManut
                                    from Famiglia F inner join Pianta P
											on F.idFamiglia = P.Famiglia
                                        inner join Esemplare E
											on P.idPianta = E.Pianta
                                    where E.idEsemplare = _Esemplare
                                    );
		#Se l'indice di manutenzione è basso dobbiamo solo aggiungere o una concimazione o un trattamento (a seconda delle probabilità di attacco e 
        #di carenza di elementi)
		if(@IndiceManutenzione < 3) then
			set @MaxAttacco = (
								select max(Probabilita)
                                from PeriodoAttacchi PA inner join Esemplare E
									on PA.Pianta = E.Pianta
                                where E.idEsemplare = _Esemplare and
									Probabilita < 50
                                );
			set @TotElementi = 10 * (
										select count(*)
                                        from EsigenzeElemento EE inner join Esemplare E
											on EE.Pianta = E.Pianta
										where E.idEsemplare = _Esemplare
                                        );
			if(@MaxAttacco >= @TotElementi) then
				call ProcedureAggiungiTrattamento (_Esemplare, @IndiceManutenzione, 0);
			else call ProcedureAggiungiConcimazione(_Esemplare, @IndiceManutenzione, 0);
            end if;
		#Se l'indice di manutenzione è medio dobbiamo aggiungere 1 concimazione e 1 trattamento il primo anno e poi bisogna decidere per il secondo
        elseif(@IndiceManutenzione >= 3 and @IndiceManutenzione < 5) then
            set @MaxAttacco = (
								select max(Probabilita)
                                from PeriodoAttacchi PA inner join Esemplare E
									on PA.Pianta = E.Pianta
                                where E.idEsemplare = _Esemplare
                                );
			set @TotElementi = 10 * (
										select count(*)
                                        from EsigenzeElemento EE inner join Esemplare E
											on EE.Pianta = E.Pianta
										where E.idEsemplare = _Esemplare
                                        );
			if(@MaxAttacco >= @TotElementi) then
				call ProcedureAggiungiTrattamento (_Esemplare, @IndiceManutenzione, 1, _Tipo);
                call ProcedureAggiungiConcimazione (_Esemplare, @IndiceManutenzione, 0, _Tipo);
			else call ProcedureAggiungiConcimazione(_Esemplare, @IndiceManutenzione, 1, _Tipo);
				call ProcedureAggiungiTrattamento(_Esemplare, @IndiceManutenzione, 0, _Tipo);
            end if;
		#Se l'indice di manutenzione è alto dobbiamo aggiungere 2 concimazioni e 2 trattamenti il primo anno e poi 1 e 1 il secondo
		elseif(@IndiceManutenzione >= 5) then
			call ProcedureAggiungiTrattamento (_Esemplare, @IndiceManutenzione, 0, _Tipo);
			call ProcedureAggiungiConcimazione(_Esemplare, @IndiceManutenzione, 0, _Tipo);
        end if;
    end if;
    
    
    close PeriodiConcimazioni;
    close PeriodiPotature;
    close PeriodiAttacchi;
end $$

create procedure ProcedureAggiungiTrattamento(in _Esemplare int, in IndiceManutenzione double, in SecondoAnno int, in _Tipo varchar(45))
begin
	declare _Pianta int;
    declare AgenteProbabile int;
    declare AgenteSecondo int;					
    set _Pianta = (
					select Pianta
                    from Esemplare
                    where idEsemplare = _Esemplare
                    );
	set AgenteProbabile = (
							select Agente
                            from PeriodoAttacchi
                            where Pianta = _Pianta and
								Probabilita = (
												select max(Probabilita)
                                                from PeriodoAttacchi
                                                where Pianta = _Pianta and
													Probabilita < 50
                                                    )
							limit 1
                            );
	#Il secondo agente più probabile ci serve solo in caso si abbia un indice di manutenzione alto
	if (IndiceManutenzione >= 5) then
		set AgenteSecondo = (
								select Agente
                                from PeriodoAttacchi
                                where Pianta = _Pianta and
									Agente <> AgenteProbabile
                                    and Probabilita = (
														select max(Probabilita)
														from PeriodoAttacchi
                                                        where Pianta = _Pianta and
															Probabilita < 50 and
                                                            Agente <> AgenteProbabile
                                                            )
									limit 1
								);
    end if;
    #Selezioniamo il periodo dove c'è la maggior probabilità di attacco
    set @InizioPeriodo = (
								select InizioPeriodo
                                from PeriodoAttacchi
                                where Pianta = _Pianta and
									Agente = AgenteProbabile
                                    and Probabilita = (
														select max(Probabilita)
														from PeriodoAttacchi
                                                        where Pianta = _Pianta and
															Probabilita < 50 
                                                            )
									limit 1
								);
	set @FinePeriodo = (
								select FinePeriodo
                                from PeriodoAttacchi
                                where Pianta = _Pianta and
									Agente = AgenteProbabile and
                                    InizioPeriodo = @InizioPeriodo
                                    and Probabilita = (
														select max(Probabilita)
														from PeriodoAttacchi
                                                        where Pianta = _Pianta and
															Probabilita < 50 
                                                            )
								);
	#Prendiamo la metà del periodo		
	set @MetaPeriodo = (@FinePeriodo - @InizioPeriodo) / 2;
    
    #Controlliamo che il periodo non sia già passato
    if (@InizioPeriodo < month(current_date()))then
		set @MesiDiDistanza = 12 - month(current_date()) + @InizioPeriodo;
	else set @MesiDiDistanza = @InizioPeriodo - month(current_date());
    end if;
    
	#Inserimento in intervento
	insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
		#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + Metà Periodo
		(current_date() + interval (@MesiDiDistanza) month + interval (@MetaPeriodo) month, _Tipo,
			'Trattamento', _Esemplare);
	
    #Recuperiamo l'id dell'intervento appena inserito
    set @InterventoInserito = (
								select idIntervento
                                from Intervento
                                where Esemplare = _Esemplare and
									Tipo = 'Trattamento' and
                                    idIntervento not in (
															select Intervento
                                                            from Trattamento
                                                            )
								);
    
    #Inseriamo in trattamento
    insert into Trattamento (`Intervento`, `Agente`, `Prevenzione`) values
		(@InterventoInserito, AgenteProbabile, 1);
    
    #Solo nel caso di esemplari ad alta manutenzione o a media manutenzione, ma con alta probabilità di attacchi, facciamo un'altra insert per il secondo anno
    if(@IndiceManutenzione >= 5 or Secondo = 1) then
		#Inserimento in intervento
		insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
			#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + 1 anno + Metà Periodo
			(current_date() + interval (@MesiDiDistanza + 12) month + interval (@MetaPeriodo) month, _Tipo,
				'Trattamento', _Esemplare);
		
		#Recuperiamo l'id dell'intervento appena inserito
		set @InterventoInserito = (
									select idIntervento
									from Intervento
									where Esemplare = _Esemplare and
										Tipo = 'Trattamento' and
										idIntervento not in (
																select Intervento
																from Trattamento
																)
									);
    
		#Inseriamo in trattamento
		insert into Trattamento (`Intervento`, `Agente`, `Prevenzione`) values
			(@InterventoInserito, AgenteProbabile, 1);
    end if;
    
    #-------------------------------------------------------------------------------------------------------
	#		CASO ESEMPLARE AD ALTA MANUTENZIONE, SECONDO AGENTE PIU' PROBABILE
    #-----------------------------------------------------------------------------------------------------
    
    #Nel caso di un esemplare ad alta manutenzione, bisogna aggiungere un trattamento nel corso del primo anno
    if(@IndiceManutenzione >= 5)then
		#Selezioniamo il periodo dove c'è la maggior probabilità di attacco
		set @InizioPeriodo = (
									select InizioPeriodo
									from PeriodoAttacchi
									where Pianta = _Pianta and
										Agente = AgenteSecondo
										and Probabilita = (
															select max(Probabilita)
															from PeriodoAttacchi
															where Pianta = _Pianta and
																Probabilita < 50 and
																Agente <> AgenteProbabile
															)
										limit 1
									);
		set @FinePeriodo = (
									select FinePeriodo
									from PeriodoAttacchi
									where Pianta = _Pianta and
										Agente = AgenteSecondo and
                                        InizioPeriodo = @InizioPeriodo
										and Probabilita = (
															select max(Probabilita)
															from PeriodoAttacchi
															where Pianta = _Pianta and
																Probabilita < 50 and
																Agente <> AgenteProbabile
																)
									);
		#Prendiamo la metà del periodo		
		set @MetaPeriodo = (@FinePeriodo - @InizioPeriodo) / 2;
    
		#Controlliamo che il periodo non sia già passato
		if (@InizioPeriodo < month(current_date()))then
			set @MesiDiDistanza = 12 - month(current_date()) + InizioPeriodo;
		else set @MesiDiDistanza = InizioPeriodo - month(current_date());
		end if;
    
		#Inserimento in intervento
		insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
			#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
			#A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
			(current_date() + interval (@MesiDiDistanza) month + interval (@MetaPeriodo) month, _Tipo,
				'Trattamento', _Esemplare);
	
		#Recuperiamo l'id dell'intervento appena inserito
		set @InterventoInserito = (
									select idIntervento
									from Intervento
									where Esemplare = _Esemplare and
										Tipo = 'Trattamento' and
										idIntervento not in (
																select Intervento
																from Trattamento
																)
									);
    
		#Inseriamo in trattamento
		insert into Trattamento (`Intervento`, `Agente`, `Prevenzione`) values
			(@InterventoInserito, AgenteSecondo, 1);
    end if;
end $$

create procedure ProcedureAggiungiConcimazione(in _Esemplare int, in IndiceManutenzione double, in Secondo int, in _Tipo varchar(45))
begin
	declare _Pianta int;
    declare ConcimazioneMigliore int;
    declare ConcimazioneSeconda int;
    
	set _Pianta = (
					select Pianta
                    from Esemplare
                    where idEsemplare = _Esemplare
                    );
	
    #RECUPERO CONCIMAZIONI MIGLIORI
    
	set ConcimazioneMigliore = (
									select UE.Concimazione
                                    from UtilizzoElemento UE inner join EsigenzeElemento EE
										on UE.Elemento = EE.Elemento
									group by UE.Concimazione
                                    having count(distinct UE.Elemento) >= all(
																				select count(*)
                                                                                from UtilizzoElemento UE1 inner join EsigenzeElemento EE1
																					on UE1.Elemento = EE1.Elemento
																				group by UE1.Concimazione
                                                                                )
									limit 1
								);
	set ConcimazioneSeconda = (
									select UE.Concimazione
                                    from UtilizzoElemento UE inner join EsigenzeElemento EE
										on UE.Elemento = EE.Elemento
									where UE.Concimazione <> ConcimazioneMigliore
									group by UE.Concimazione
                                    having count(distinct UE.Elemento) >= all(
																				select count(*)
                                                                                from UtilizzoElemento UE1 inner join EsigenzeElemento EE1
																					on UE1.Elemento = EE1.Elemento
																				where UE1.Concimazione <> ConcimazioneMigliore
																				group by UE1.Concimazione
                                                                                )
									limit 1
								);
	
    #------------------------------------------------------------------------------------------
    #		INSERIMENTO PRIMO INTERVENTO, NEL PRIMO ANNO
    #------------------------------------------------------------------------------------------
    
    #Recuperiamo il periodo in cui si può fare questa concimazione e la sua periodicità
    set @InizioPeriodo = (
							select InizioPeriodo
                            from TipoConcimazione
                            where idConcimazione = ConcimazioneMigliore
                            );
	set @Periodicita = (
							select Periodicita
                            from TipoConcimazione
                            where idConcimazione = ConcimazioneMigliore
                            );
    #Controlliamo se per quest'anno il periodo è già passato
	if (@InizioPeriodo < month(current_date()))then
		set @MesiDiDistanza = 12 - month(current_date()) + @InizioPeriodo;
	else set @MesiDiDistanza = @InizioPeriodo - month(current_date());
	end if;
	set @NumeroInterventi = (
								select count(*)
								from Concimazione
								where TipoConcimazione = ConcimazioneMigliore
								);
    set @NumeroConcimazione = 1;
	#Loop che controlla l'inserimento di tutti gli interventi di concimazione singoli
	inserimentoIntervento: loop
		if(@NumeroConcimazione >= @NumeroInterventi + 1) then
			leave inserimentoIntervento;
		end if;
		#Inserimento in intervento
		insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
			#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
			#A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
			(current_date() + interval (@MesiDiDistanza) month + interval (@NumeroConcimazione * @Periodicita) week, _Tipo,
				'Concimazione', _Esemplare);
			
		#Recuperiamo l'id dell'intervento appena inserito, necessario per il prossimo inserimento
		set @InterventoInserito = (
									select idIntervento
									from Intervento
									where Data = current_date() + interval (@MesiDiDistanza) month + interval (@NumeroConcimazione * @Periodicita) week
										and	Esemplare = _Esemplare and
										Tipo = 'Concimazione' and
										#Poiché dobbiamo ancora fare la insert in TipoInterventoConcimazione, non esiste ancora un'occorrenza del genere
										idIntervento not in
															(
																select Intervento
																from TipoInterventoConcimazione
																)
									);
		#Inserimento in TipoInterventoConcimazione
		insert into TipoInterventoConcimazione values
			(@InterventoInserito, @NumeroConcimazione, ConcimazioneMigliore);
		set @NumeroConcimazione = @NumeroConcimazione + 1;
	end loop;
    
    #---------------------------------------------------------------------------------------------------------------
    #		INSERIMENTO PRIMO INTERVENTO, SECONDO ANNO
    #---------------------------------------------------------------------------------------------------------------
    
    #Se l'esemplare è ad alta manutenzione o ha bisogno di molti elementi, inseriamo un intervento nel secondo anno
    #Ripetiamo quindi il loop, aggiungendo 12 mesi nella data
	if(@IndiceManutenzione >= 5 or Secondo = 1) then
		#Loop che controlla l'inserimento di tutti gli interventi di concimazione singoli
		inserimentoIntervento: loop
			if(@NumeroConcimazione >= @NumeroInterventi + 1) then
				leave inserimentoIntervento;
			end if;
			#Inserimento in intervento
			insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
				#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
				#A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
				(current_date() + interval (@MesiDiDistanza + 12) month + interval (@NumeroConcimazione * @Periodicita) week, _Tipo,
					'Concimazione', _Esemplare);
			
			#Recuperiamo l'id dell'intervento appena inserito, necessario per il prossimo inserimento
			set @InterventoInserito = (
										select idIntervento
										from Intervento
										where Data = current_date() + interval (@MesiDiDistanza + 12) month + interval (@NumeroConcimazione * @Periodicita) week
											and	Esemplare = _Esemplare and
											Tipo = 'Concimazione' and
											#Poiché dobbiamo ancora fare la insert in TipoInterventoConcimazione, non esiste ancora un'occorrenza del genere
											idIntervento not in
																(
																	select Intervento
																	from TipoInterventoConcimazione
																	)
										);
			#Inserimento in TipoInterventoConcimazione
			insert into TipoInterventoConcimazione values
				(@InterventoInserito, @NumeroConcimazione, ConcimazioneMigliore);
			set @NumeroConcimazione = @NumeroConcimazione + 1;
		end loop;
    end if;
    
    #---------------------------------------------------------------------------------------------------------
    #		SECONDO INTERVENTO, PRIMO ANNO
    #---------------------------------------------------------------------------------------------------------
    
    #Se l'esemplare è ad alta manutenzione, allora necessità di una seconda concimazione nel primo anno
	if(@IndiceManutenzione >= 5) then
		#Recuperiamo il periodo in cui si può fare questa concimazione e la sua periodicità
		set @InizioPeriodo = (
								select InizioPeriodo
								from TipoConcimazione
								where idConcimazione = ConcimazioneSeconda
								);
		set @Periodicita = (
								select Periodicita
								from TipoConcimazione
								where idConcimazione = ConcimazioneSeconda
								);
		#Controlliamo se per quest'anno il periodo è già passato
		if (@InizioPeriodo < month(current_date()))then
			set @MesiDiDistanza = 12 - month(current_date()) + @InizioPeriodo;
		else set @MesiDiDistanza = @InizioPeriodo - month(current_date());
		end if;
		set @NumeroInterventi = (
									select count(*)
									from Concimazione
									where TipoConcimazione = ConcimazioneSeconda
									);
		set @NumeroConcimazione = 1;
		#Loop che controlla l'inserimento di tutti gli interventi di concimazione singoli
		inserimentoIntervento: loop
			if(@NumeroConcimazione >= @NumeroInterventi + 1) then
				leave inserimentoIntervento;
			end if;
			#Inserimento in intervento
			insert into Intervento (`Data`, `Motivo`, `Tipo`, `Esemplare`) values
				#Il valore della data è costituito così: DataCorrente + Mesi di distanza dall'inizio del periodo + i anni (dove i è il contatore esterno)
				#A questo valore si aggiungono tante settimane, quante ne richiede la periodicità (e il numero dell'intervento che stiamo inserendo)
				(current_date() + interval (@MesiDiDistanza) month + interval (@NumeroConcimazione * @Periodicita) week, _Tipo,
					'Concimazione', _Esemplare);
			
			#Recuperiamo l'id dell'intervento appena inserito, necessario per il prossimo inserimento
			set @InterventoInserito = (
										select idIntervento
										from Intervento
										where Data = current_date() + interval (@MesiDiDistanza) month + interval (@NumeroConcimazione * @Periodicita) week
											and	Esemplare = _Esemplare and
											Tipo = 'Concimazione' and
											#Poiché dobbiamo ancora fare la insert in TipoInterventoConcimazione, non esiste ancora un'occorrenza del genere
											idIntervento not in
																(
																	select Intervento
																	from TipoInterventoConcimazione
																	)
										);
			#Inserimento in TipoInterventoConcimazione
			insert into TipoInterventoConcimazione values
				(@InterventoInserito, @NumeroConcimazione, ConcimazioneSeconda);
			set @NumeroConcimazione = @NumeroConcimazione + 1;
		end loop;
    end if;
end $$

delimiter ;




#Event con cui ci si assicura che non siano stati inseriti due terreni uguali; se ci sono dei duplicati, questi vengono inseriti 
#in una materialized view
#Creiamo la materialized view
drop table if exists MV_TerreniDuplicati;
create table MV_TerreniDuplicati (
	Terreno int,
    primary key( Terreno) 
) Engine = InnoDB default charset = latin1;

drop procedure if exists ProcedureAggiornaTerreniDuplicati;

delimiter $$

create procedure ProcedureAggiornaTerreniDuplicati()
begin
	declare finito int default 0;
    declare TerrenoPerCuiEsisteDuplicato int default 0;
	declare TerreniPerCuiEsisteUnDuplicato cursor for
		#Incominciamo con prendere un terreno ID
		select idTerreno
		from Terreno T
		where exists (
						#Troviamo i terreni ID1 tali che hanno uguali proprietà a ID
						select *
						from Terreno T1
						where T.idTerreno <> T1.idTerreno and
							T.Consistenza = T1.Consistenza and
							T.Permeabilita = T1.Permeabilita and
							T.pH = T1.pH and
                            #In più, deve sussistere questa proprietà:
                            #per ogni record di composizione terreno avente come terreno ID ne deve esistere
                            #uno uguale per ID1.
                            #Per assicurarci che sia così, contiamo i record di Composizione terreno che fanno join
                            #secondo questa proprietà e controlliamo che il loro numero sia uguale a quello dei record
                            #con terreno uguale a ID e a quello dei record con terreno uguale a ID1
							(
								select count(*)
								from ComposizioneTerreno CT inner join ComposizioneTerreno CT1
									on (CT.Elemento = CT1.Elemento and CT.Concentrazione = CT1.Concetrazione)
								where CT.Terreno = T.idTerreno and CT1.Terreno = T1.idTerreno
							) =
							(
								select count(*)
								from ComposizioneTerreno
								where Terreno = T.idTerreno
							) and
							(
								select count(*)
								from ComposizioneTerreno CT inner join ComposizioneTerreno CT1
									on (CT.Elemento = CT1.Elemento and CT.Concentrazione = CT1.Concetrazione)
								where CT.Terreno = T.idTerreno and CT1.Terreno = T1.idTerreno
							) =
							(
								select count(*)
								from ComposizioneTerreno
								where Terreno = T.idTerreno
							) 
					);
    declare continue handler
		for not found set finito = 1;
        
	truncate table MV_TerreniDuplicati;
    
	open TerreniPerCuiEsisteUnDuplicato;
    
    prelievo: loop
		fetch TerreniPerCuiEsisteUnDuplicato into TerrenoPerCuiEsisteDuplicato;
        if (finito = 1) then
			leave prelievo;
		end if;
		insert into MV_TerreniDuplicati (`Terreno1`) values
			(TerrenoPerCuiEsisteDuplicato);
	end loop;	
    
    close TerreniPerCuiEsisteUnDuplicato;
end $$

delimiter ;

drop event if exists AggiornaTerreniDuplicati;

delimiter $$

create event AggiornaTerreniDuplicati
on schedule every 1 week
starts '2016-06-13 00:00:01'
do
begin
	call ProcedureAggiornaTerreniDuplicati();
end $$

delimiter ;
#La procedure che segue permette all'utente di aggiungere in maniera semplice una nuova pianta in un dato settore, eventualmente associata ad un vaso
drop procedure if exists ProcedureAggiuntaPiantaSettore;

delimiter $$

create procedure ProcedureAggiuntaPiantaSettore (in SettoreInCuiAggiungere int, in PiantaDaAggiungere int, in Ascissa int, in Ordinata int, in AggiuntaVaso bool)
begin
	#Prima di tutto controlliamo che il settore sia completato (in realtà c'è un trigger apposito, ma meglio intervenire subito in caso di errore)
    set @Finito = (
					select if(count(*) >= 3, 1, 0)
                    from Punto
                    where Settore = SettoreInCuiAggiungere
                    );
	if (@Finito = 0) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Per poter inserire delle piante, devi prima aver completato il settore!';
    end if;
	#Controlliamo poi qual è la posizione che la pianta andrà ad occupare nel settore
    set @PosPianta = (
						select max(PosPianta)
                        from FormaPianta
                        where Settore = SettoreInCuiAggiungere
                        ) + 1;
	#Calcoliamo la dimensione come la dimensione massima della pianta
    set @Dimensione = (
						select DimMax
                        from Pianta
                        where idPianta = PiantaDaAggiungere
                        );
	#Effettuiamo quindi la insert vera e propria
    insert into FormaPianta (`X`, `Y`, `Settore`, `Pianta`, `PosPianta`, `Dim`) values
		(Ascissa, Ordinata, SettoreInCuiAggiungere, PiantaDaAggiungere, @PosPianta, @Dimensione);
	#Occupiamoci quindi del vaso
	signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Per poter inserire delle piante, devi prima aver completato il settore!';
    if(AggiuntaVaso = true) then
		#Si suppone che l'utente deciderà in un secondo momento il materiale del vaso
		insert into Vaso (`PosizionePianta`, `Dimensione`, `Pianta`, `Settore`) values
			(@PosPianta, @Dimensione, PiantaDaAggiungere, SettoreInCuiAggiungere);
    end if;
end $$


delimiter ;
#Procedure con cui avanziamo lo stato dell'ordine
drop procedure if exists AvanzaStatoOrdine;

delimiter $$

create procedure AvanzaStatoOrdine ( in OrdineDaAvanzare int)
begin
	#Se l'ordine non esiste, vuol dire che c'è un errore di immissione
	if(not exists(
				select *
                from Ordine
                where OrdineDaAvanzare = idOrdine
                )) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Quest ordine non esiste';
	end if;
	set @StatoOrdine = (
							select Stato
                            from Ordine
                            where OrdineDaAvanzare = idOrdine
						);
	#A seconda di qual era lo stato precedente, la procedure si comporta nei seguenti modi
    #Se l'ordine era pendente non fa nulla (in quel caso ci pensa un trigger apposito, non l'utente)
    if(@StatoOrdine = 'Pendente') then
		signal sqlstate "45000"
        set message_text = 'Quest ordine non può cambiare di stato finché non arrivano le piante richieste';  
	#Se l'ordine era già stato Evaso, la procedure non fa nulla
	elseif(@StatoOrdine = 'Evaso') then
		signal sqlstate "45000"
        set message_text = 'Quest ordine risulta già evaso';  
	#Se l'ordine non è né pendente né evaso, la procedure calcola il nuovo valore da far assumere allo stato dell'ordine
    elseif(@StatoOrdine = 'InProcessazione') then
		set @NuovoStato = 'InPreparazione';
	elseif(@StatoOrdine = 'InPreparazione') then
		set @NuovoStato = 'Spedito';
	elseif(@StatoOrdine = 'Spedito') then
		set @NuovoStato = 'Evaso';
	end if;
    #A questo punto si può fare l'update
    update Ordine
    set Stato = @NuovoStato
    where idOrdine = OrdineDaAvanzare;
end $$

delimiter ;

drop procedure if exists ProcedureCalcolaDimensioneEsemplare;

delimiter $$

create procedure ProcedureCalcolaDimensioneEsemplare (in DataNascita Date , in PiantaEsemplare int  , out Dimensione double )
begin
	declare MesiDiVita int default 0;
    declare Indice double;
    declare DimMassima double;
    declare Rapporto double;
    #Calcoliamo i mesi di vita dell'esemplare
    set MesiDiVita = month(current_date()) - month(DataNascita) + 1;
    
    
    
	#Calcoliamone l'indice di accrescimento
	set Indice = (
					select F.CrescitaAerea
                    from Famiglia F inner join Pianta P
						on F.idFamiglia = P.Famiglia
                    where PiantaEsemplare = P.idPianta
					);
	
    if(Indice is NULL)then
		set Indice = 1;
	end if;
	
	#Calcoliamo la dimensione massima che può raggiungere
	set DimMassima = (
						select P.DimMax
                        from Pianta P
						where PiantaEsemplare = P.idPianta
                        );
	#Calcoliamo il rapporto fra la dimensione attuale e quella massima
	set Rapporto = 1 - 1/(Indice * MesiDiVita + 1);
    #Restituiamo la dimensione attuale
    set Dimensione = Rapporto * DimMassima;
    
end $$

delimiter ;

#Questa procedure calcola a partire da un esemplare, la sua dimensione attuale
drop procedure if exists ProcedureCalcolaDimensioneAereaPianta;

delimiter $$

create procedure ProcedureCalcolaDimensioneAereaPianta (in Esemplare int, out DimAerea double)
begin
	declare MesiDiVita int default 0;
    declare Indice double;
    declare DimMassima double;
    #Calcoliamo i mesi di vita dell'esemplare
    set MesiDiVita = (
						select month(current_date()) - month(DataNascita) +1
                        from Esemplare
                        where idEsemplare = new.Esemplare
						);
	#Calcoliamone l'indice di accrescimento
	set Indice = (
					select F.CrescitaAerea
                    from Famiglia F inner join Pianta P
						on F.idFamiglia = P.Famiglia
                        inner join Esemplare E
                        on P.idPianta = E.Pianta
					where idEsemplare = new.Esemplare
					);
	#Calcoliamo la dimensione massima che può raggiungere
	set DimMassima = (
						select P.DimMax
                        from Pianta P inner join Esemplare E
							on P.idPianta = E.Pianta
						where idEsemplare = new.Esemplare
                        );
	#Calcoliamo il rapporto fra la dimensione attuale e quella massima
	set @Rapporto = 1 - 1/(Indice * MesiDiVita + 1);
    #Restituiamo la dimensione attuale
    set DimAerea = @Rapporto * DimMassima;
end $$

delimiter ;

drop procedure if exists ProcedureCalcolaDimensioneRadicalePianta;

delimiter $$

create procedure ProcedureCalcolaDimensioneRadicalePianta (in Esemplare int, out DimRadicale double)
begin
	declare MesiDiVita int default 0;
    declare Indice double;
    declare DimMassima double;
    #Calcoliamo i mesi di vita dell'esemplare
    set MesiDiVita = (
						select month(current_date()) - month(DataNascita) +1
                        from Esemplare
                        where idEsemplare = new.Esemplare
						);
	#Calcoliamone l'indice di accrescimento
	set Indice = (
					select F.CrescitaRadicale
                    from Famiglia F inner join Pianta P
						on F.idFamiglia = P.Famiglia
                        inner join Esemplare E
                        on P.idPianta = E.Pianta
					where idEsemplare = new.Esemplare
					);
	#Calcoliamo la dimensione massima che può raggiungere
	set DimMassima = (
						select P.DimMax
                        from Pianta P inner join Esemplare E
							on P.idPianta = E.Pianta
						where idEsemplare = new.Esemplare
                        );
	#Calcoliamo il rapporto fra la dimensione attuale e quella massima
	set @Rapporto = 1 - 1/(Indice * MesiDiVita + 1);
    #Restituiamo la dimensione attuale
    set DimRadicale = @Rapporto * DimMassima;
end $$

delimiter ;

#Trigger che crea un nuovo ordine; per farlo esegue le seguenti azioni:
#Crea una nuova occorrenza della tabella 'Ordine';
#Trova gli esemplari disponibili per la specie di pianta che ci interessa (eliminando quindi sia quelli già venduti, sia quelli malati);
#Per ogni esemplare trovato, crea una nuova occorrenza di 'Relativo';
#Se gli esemplari disponibili non sono sufficienti, crea una nuova occorrenza di 'Pendente';
drop procedure if exists ProcedureCreaNuovoOrdine;

delimiter $$

create procedure ProcedureCreaNuovoOrdine (in Buyer int, in PiantaAcquistata int, in HowMany int)
begin
	declare finito int default 0;
    declare TimestampAttuale timestamp;
    declare EsemplariMancanti int default 0;
    declare EsemplareVenduto int default 0;
	#Recuperiamo 'HowMany' esemplari disponibili per questa pianta (o comunque quelli che abbiamo al momento)
    declare EsemplariDisponibili cursor for
		select idEsemplare
        from Esemplare
        where Malato = false and
			Venduto = false and
            Pianta = PiantaAcquistata
		limit HowMany;
	declare continue handler for
		not found set finito =1;
	
    set TimestampAttuale = current_timestamp();
    
	#Controlliamo se il numero di esemplari disponibili è sufficiente a coprire l'ordine
	set EsemplariMancanti = HowMany - (
										select count(*)
										from Esemplare
										where Malato = false and
											Venduto = false and
											Pianta = PiantaAcquistata
									);
	
    
    
    #Creiamo la nuova occorrenza di ordine
    insert into Ordine(`Timestamp`, `Account`) values
		(TimestampAttuale, Buyer);
        
    
    #Recuperiamo l'id dell'ordine appena creato
		set @OrdineCreato = (
								select idOrdine							
								from Ordine									
								where Account = Buyer and
									TimeStamp = TimeStampAttuale
								limit 1
								);
    
    #Se gli esemplari disponibili non erano sufficienti, si crea un'occorrenza in Pendente
	if(EsemplariMancanti > 0) then
		
		#Facciamo l'inserimento in 'Pendente'
		insert into Pendente (`Ordine`, `Pianta`, `Quantita`) values
			(@OrdineCreato, PiantaAcquistata, EsemplariMancanti);
	end if;

    #Passiamo ora alla creazione dell'ordine
    open EsemplariDisponibili;
    
	prelievo: loop
		fetch EsemplariDisponibili into EsemplareVenduto;
        if(finito = 1) then
			leave prelievo;
		end if;
        
        #Aggiorniamo gli esemplari in questione cambiando il valore di 'venduto'
		update Esemplare
        set venduto = true
        where idEsemplare = EsemplareVenduto;
        
        #Creiamo le occorrenze di relativo
        insert into Relativo (`Ordine`, `Esemplare`) values
			(@OrdineCreato, EsemplareVenduto);
	end loop;
    
    close EsemplariDisponibili;
end $$

delimiter ;

#Stored procedure che restituisce come result set gli interventi da effettuare o già effettuati da un dato esemplare
drop procedure if exists ProcedureListaInterventi;

delimiter $$

create procedure ProcedureListaInterventi (in _Esemplare int)
begin
	select *
    from Intervento
    where Esemplare = _Esemplare;
end $$

delimiter ;

#Procedure con cui si mostrano a video le misurazioni relative ad un dato esemplare, in una specifica data
drop procedure if exists ProcedureListaMisurazioni;

delimiter $$

create procedure ProcedureListaMisurazioni(in _Esemplare int, in _Timestamp int)
begin
	#Selezioniamo il contenitore relativo all'esemplare
	set @Contenitore = (
							select idContenitore
                            from Contenitore
                            where Esemplare = _Esemplare
                            );
	#Selezioniamo la sezione
	set @Sezione = (
						select idSezione
                        from Sezione S inner join Ripiano R
							on S.idSezione = R.Sezione
                            inner join Contenitore C
							on R.idRipiano = C.Ripiano
                        where Contenitore = @Contenitore
                        );
	#Individuiamo le misurazioni						
	select *
    from MisurazioneContenitore MC,
		MisurazioneAmbientale MA
	where MC.TimeStamp = _Timestamp and
		MA.TimeStamp = _Timestamp and
        MC.Contenitore = @Contenitore and
        MA.Sezione = @Sezione;
end $$

delimiter ;

#Procedure che popola una temporary table contenente le piante consigliate per un settore.
#Si utilizza lo strumento della stored procedure così da poterla richiamare anche quando cambiano le condizioni di un settore.
#Il procedimento che si segue è questo:
# - In base all'indice di manutenzione e al clima del giardino, si fa una prima selezione delle piante (come in ProcedureValutazionePreferenze)
# - Il terreno (se il settore non è pavimentato), fornisce un ulteriore elemento di selezione
# - Il costo viene valutato in base al costo medio delle piante acquistate dall'utente negli ultimi 6 mesi (di default è medio)
# - Infine si dà maggior priorità alle piante che coprono un periodo di fioritura il più ampio possibile fra i periodi non ancora coperti dalle
#   piante del settore

drop procedure if exists ProcedureSuggerimentoSettore;

delimiter $$

create procedure ProcedureSuggerimentoSettore(in _Settore int)
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare CostoBaseSingolo double;
    declare IndiceManutSingolo double;
    declare TemperaturaSingola double;
    declare LuceSingola int;
    declare TerrenoSingolo int;
	#Prendiamo tutte le piante presenti nel sistema
    declare PianteSistema cursor for
		select idPianta,
            CostoBase,
            IndiceManut
        from Pianta;
        
	declare continue handler for
		not found set finito = 1;
        
    #------------------------------------------------------------------------------------------------------------------------
    #		CALCOLO INFORMAZIONI SETTORE
    #------------------------------------------------------------------------------------------------------------------------    
	
	#Individuiamo a quale account appartiene il settore
    set @Account = (
					select Account
                    from Settore
                    where idSettore = _Settore
                    );
    
    #CALCOLO DEL COSTO
        
    #Calcoliamo il costo medio delle piante acquistate dall'utente
    set @CostoMedio = (
						select avg(Prezzo)
                        from Esemplare E inner join Scheda S
							on E.idEsemplare = S.Esemplare
                        where S.Account = @Account and
							S.DataAcquisto > current_date() - interval 6 month
                        );

    #Convertiamolo nel range corrispondente
    case
		when @CostoMedio < 15 then
			set @Costo = 'Basso';
		when @CostoMedio between 15 and 30 then
			set @Costo = 'MedioBasso';
		when @CostoMedio is null or @CostoMedio between 30 and 60 then #Di default mettiamo a 'Medio'
			set @Costo = 'Medio';
		when @CostoMedio between 60 and 100 then
			set @Costo = 'MedioAlto';
		when @CostoMedio > 100 then
			set @Costo = 'Alto';
		ELSE BEGIN END;  
    end case;
	
    #CALCOLO DELL'INDICE DI MANUTENZIONE
    set @IndiceManut = (
							select IndiceManut
                            from Giardino G inner join Settore S
								on (G.Account = S.Account and
									G.Numero = S.NumeroGiardino)
                            where S.idSettore = _Settore
                            );
	if (@IndiceManut is null) then	#Valore di default
		set @IndiceManut = 'Medio';
    end if;
    
	#CALCOLO DELLA TEMPERATURA
    set @Temperatura = (
							select Clima
                            from Giardino G inner join Settore S
								on (G.Account = S.Account and
									G.Numero = S.NumeroGiardino)
                            where S.idSettore = _Settore
                            );
    if (@Temperatura is null) then	#Valore di default
		set @Temperatura = 'Medio';
    end if;
    
    #CALCOLO DEL TERRENO
    set @Terreno = (
						select Terreno
                        from Settore
						where idSettore = _Settore
						);
                            
	
    #CALCOLO DELLA LUCE
    #Se non si è aggiornata la luce attuale, prendiamo la luce iniziale del settore
    set @LuceAttuale = (
					select LuceAttuale
                    from Settore
                    where idSettore = _Settore
                    );                   
                    
	if (@LuceAttuale is null) then
		set @LuceAttuale = (
								select LuceIniziale
                                from Settore
                                where idSettore = _Settore
                                );
    end if;
	
	#Calcoliamo il coefficiente di luminosità per la luce del settore
	set @CoefficienteLuce = (
							select if(L.Quantita = 'Bassa', @Quantita := 1,
									if(L.Quantita = 'Media', @Quantita := 3, @Quantita := 5)) * L.NumOre *
                                    if(L.Diretta = 1, 2, 1)
							from Luce L
                            where idLuce = @LuceAttuale
                            );
    #Convertiamo la luce in un range
    set @Luce = '';
    if @CoefficienteLuce < 20 then
		set @Luce = 'Bassa';
	elseif @CoefficienteLuce between 20 and 80 then
		set @Luce = 'Media';
	elseif @CoeffucienteLuce > 80 then
		set @Luce = 'Alta';
	end if;
                      
	#------------------------------------------------------------------------------------------------------------------------
    #		CALCOLO PIANTE CONSIGLIATE
    #------------------------------------------------------------------------------------------------------------------------
    drop temporary table if exists PianteSuggeriteSettore;
    create temporary table PianteSuggeriteSettore(
		Pianta int not null,
        Settore int not null,
        CompatibilitaTerreno int,
        MesiCoperti int,
        primary key (Pianta, Settore)
    )Engine = InnoDB default charset = latin1;
    
    open PianteSistema;
    
    prelievo: loop
		fetch PianteSistema into PiantaSingola, CostoBaseSingolo, IndiceManutSingolo;
        if (finito = 1) then
			leave prelievo;
        end if;
		
        #I controlli che seguono sono pressoché identici a quelli presenti in ProcedureValutazionePreferenze, a parte il fatto che qui non
        #sono presenti le variazioni di range causati dalle importanze
        
        #GESTIONE COSTO
        case
			when @Costo is not null and @Costo = 'Basso' then		
				if(CostoBaseSingolo > 15) then			
					iterate prelievo;											
                end if;																
                                                                                    
			when @Costo is not null and @Costo = 'MedioBasso' then	
				if(CostoBaseSingolo <= 15 or			
					CostoBaseSingolo > 30 ) then 		
					iterate prelievo;												
				end if;																
			
            when @Costo is not null and @Costo = 'Medio' then	
				if(CostoBaseSingolo <= 30 or	
					CostoBaseSingolo > 60) then
					iterate prelievo;	
				end if;		
                
			when @Costo is not null and @Costo = 'MedioAlto' then	
				if(CostoBaseSingolo <= 60 or		
					CostoBaseSingolo > 100) then
					iterate prelievo;	
				end if;	
                
			when @Costo is not null and @Costo = 'Alto' then	
				if(CostoBaseSingolo <= 100)then
					iterate prelievo;									
				end if;	
                
			ELSE BEGIN END;  
        end case;
        
        
        #GESTIONE INDICE MANUTENZIONE
        
        case
			
			when @IndiceManut is not null and @IndiceManut = 'Basso' then	
				if(IndiceManutSingolo > 3) then		
					iterate prelievo;												
                end if;															
			
            when  @IndiceManut is not null and @IndiceManut = 'Medio' then	
				if(IndiceManutSingolo <= 3 or	
					IndiceManutSingolo > 5) then	
					iterate prelievo;	
				end if;	
                
			when @IndiceManut is not null and @IndiceManut = 'Alto' then	
				if(IndiceManutSingolo <= 5)then	
					iterate prelievo;											
				end if;	
                
			ELSE BEGIN END;  
        end case;
        
        #GESTIONE TEMPERATURA
        
        set TemperaturaSingola = (
							select (TempMax + TempMin)/2
							from Temperatura T inner join Esigenze E
								on T.idTemp = E.Temperatura
                            where E.Pianta = PiantaSingola
                            );
        
        case
			when @Temperatura is not null and @Temperatura = 'MoltoFreddo' then	
				if(TemperaturaSingola > 7) then
					iterate prelievo;
                end if;												
                
			when @Temperatura is not null and @Temperatura = 'Freddo' then
				if(TemperaturaSingola <= 7 or
					TemperaturaSingola > 10) then	
					iterate prelievo;									
                end if;													
                
            when @Temperatura is not null and @Temperatura = 'Medio' then
				if(TemperaturaSingola <= 10 or
					TemperaturaSingola > 12) then	
					iterate prelievo;				
                end if;
            
            when @Temperatura is not null and @Temperatura = 'Caldo' then 
				if(TemperaturaSingola <= 12 or
					TemperaturaSingola > 14) then	 
					iterate prelievo;	
                end if;												
                
			when @Temperatura is not null and @Temperatura = 'MoltoCaldo' then
				if(TemperaturaSingola > 14) then	
					iterate prelievo;		
                end if;													
                
			ELSE BEGIN END;  
        end case;
        
        #GESTIONE LUCE
        
        set LuceSingola = (
							select if(L.Quantita = 'Bassa', @Quantita := 1,
									if(L.Quantita = 'Media', @Quantita := 3, @Quantita := 5)) * L.NumOre *
                                    if(L.Diretta = 1, 2, 1)
							from Luce L inner join Esigenze E
								on L.idLuce = E.LuceVegetativo  #Si considerano i periodi vegetativi perché sono quelli che richiedono pià cura
                            where E.Pianta = PiantaSingola
                            );       
                            
        case
			when @Luce is not null and @Luce = 'Basso' then		
				if(LuceSingola > 20) then
					iterate prelievo;									
                end if;									
                
            when @Luce is not null and @Luce = 'Medio' then		
				if(LuceSingola <= 20 or
					LuceSingola > 80) then	
					iterate prelievo;		
                end if;
            
            when @Luce is not null and @Luce = 'Alto' then			
				if(LuceSingola <= 80) then 
					iterate prelievo;								
                end if;
                
			ELSE BEGIN END;  
        end case;
        
        #GESTIONE TERRENO
        
        #Per il terreno, controlliamo se è compatibile con la pianta attraverso una valutazione di consistenza, permeabilità, pH ed elementi presenti
        
        if(@Terreno is not null) then
			set TerrenoSingolo = (
									select Terreno
                                    from Esigenze
                                    where Pianta = PiantaSingola
                                    );
			if (not exists (											#Prima si controlla che vi sia una compatibilità macroscopica fra il terreno
						select *										#in questione e le necessità della pianta
                        from Terreno T1 inner join Terreno T2
							on (T1.Consistenza = T2.Consistenza and
								T1.Permeabilita = T2.Permeabilita and
                                T1.pH = T2.pH)
						where T1.idTerreno = TerrenoSingolo and
							T2.idTerreno = @Terreno
                            ))then
				iterate prelievo;
			end if;
			
            #A questo punto verifichiamo se nel terreno in questione c'è almeno il 60% degli elementi necessari alla pianta
            
            #Calcoliamo il numero degli elementi necessitati
            set @NumElementi = (															
									select count(*)
                                    from EsigenzeElemento
                                    where Pianta = PiantaSingola
                                    );
            #Calcoliamo gli elementi in comune
			set @ElementiComuni = (
									select count(*)
                                    from EsigenzeElemento
                                    where Pianta = PiantaSingola and
										Elemento in (
															select Elemento
                                                            from ComposizioneTerreno
                                                            where Terreno = @Terreno
                                                            )
										);
			
			#Controlliamo la condizione
			if (@ElementiComuni < 0.6 * @NumElementi) then
				iterate prelievo;
            end if;
            
            #Settiamo ora un indice di compatibilità col terreno in base agli elementi presenti sotto forma di percentuale
            set @Compatibilita = 100*(@ElementiComuni)/@NumElementi;
        end if;
        if(@Compatibilita is null ) then
			set @Compatibilita = -1;
        end if;
        
        #GESTIONE PERIODI
        
        #Per individuare quanti periodi non coperti dalle piante attualmente nel settore vengono coperti dalla pianta su cui stiamo lavorando,
        #sfruttiamo un loop che associa ad un contatore un numero che rappresenta un mese dell'anno. Se non esiste un periodo di fioritura/fruttificazione
        #in quel mese, mentre la nuova pianta lo copre, allora aggiungiamo +1 alla variabile NumMesi, che verrà poi inserita nella tabella (così da 
        #poter poi fare un ordinamento
        
        set @Contatore = 0;
        set @NumMesi = 0;
        ControlloPeriodi: loop
			set @Contatore = @Contatore + 1;
			if(@Contatore = 13) then
				leave ControlloPeriodi;
            end if;
            #... mentre la nostra pianta lo copre...
            if(exists(
						select *
                        from PeriodoCicli PC inner join CicliPianta CP
							on PC.idPeriodo = CP.Periodo
						where CP.Pianta = PiantaSingola and
							(PC.Fio_Fru = 'Fioritura' or 
							PC.Fio_Fru = 'Fruttificazione' or
                            PC.Fio_Fru = 'Entrambi') and
							@Contatore between 
							PC.InizioPeriodo and PC.FinePeriodo
                            ))then
				#... incrementiamo NumMesi
				set @NumMesi = @NumMesi + 1;
            end if;
        end loop;
        
        
        #Se la pianta è adatta, la inseriamo
        insert into PianteSuggeriteSettore values
			(PiantaSingola, _Settore, @Compatibilita, @NumMesi);
        
	end loop;
    
    #Mostriamo a video con l'ordinamento discendente in base alla compatibilità col terreno e ai mesi coperti
    select *
    from PianteSuggeriteSettore
    order by CompatibilitaTerreno, MesiCoperti DESC;
    
end $$

delimiter ;

#Questa stored procedure calcola le piante che rispondono ad un determinato set di preferenze.
#Il funzionamento è questo:
# - Prima si eliminano le piante che non rispettano le condizioni Dioica, Infestante, Sempreverde
# - Si eliminano le piante che non rientrano nei range di Dimensione, Costo, IndiceManut; questi range sono tanto più ampi, 
#	tanto meno importanti sono per l'utente.
# - Si eliminano poi le piante che non rientrano nei range di luce, acqua e temperatura e quelle che non possono vivere nel terreno specificato
# - In generale, i valori NULL vengono sostituiti da range il più ampi possibili

drop procedure if exists ProcedureValutazionePreferenze;

delimiter $$

create procedure ProcedureValutazionePreferenze(in _IdPreferenze int)
begin
	declare finito int default 0;
    declare PiantaSingola int;
	declare DioicaSingola int;
	declare InfestanteSingolo int;
	declare SempreverdeSingolo int;
	declare DimensioneSingola double;
	declare CostoBaseSingolo double;
    declare AcquaSingola int;
    declare LuceSingola int;
    declare TemperaturaSingola int;
	declare IndiceManutSingolo double;
    declare TerrenoSingolo int;
    declare PeriodoSingolo int;
    #Prendiamo tutte le piante presenti nel sistema
    declare PianteSistema cursor for
		select idPianta,
			Dioica,
            Infestante,
            Sempreverde,
            DimMax,
            CostoBase,
            IndiceManut
        from Pianta;
        
	declare continue handler for
		not found set finito = 1;
        
	#Recuperiamo tutte le informazioni sul set di preferenze
    set @Dimensione = (
						select Dimensione
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpDimensione = (
						select ImpDimensione
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Dioica = (
						select Dioica
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Infestante = (
						select Infestante
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Temperatura = (
						select Temp
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpTemperatura = (
							select ImpTemp
							from Preferenze
							where idPreferenze=_IdPreferenze
                        );
	set @Sempreverde = (
						select Sempreverde
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Costo = (
						select Costo
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpCosto = (
						select ImpCosto
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Luce = (
						select Luce
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpLuce = (
						select ImpLuce
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Acqua = (
						select Acqua
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpAcqua = (
						select ImpAcqua
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @Terreno = (
						select Terreno
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpTerreno = (
						select ImpTerreno
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @IndiceManut = (
						select IndiceManut
                        from Preferenze
                        where idPreferenze=_IdPreferenze
                        );
	set @ImpIndiceManut = (
							select ImpIndiceManut
							from Preferenze
							where idPreferenze=_IdPreferenze
                        );
	
    open PianteSistema;
    
    #Creiamo una temporary table in cui andiamo ad inserire le piante che troviamo man mano
    create temporary table if not exists PianteConsigliate(
		Pianta int not null,
        Preferenze int not null,
        primary key(Pianta, Preferenze)
    )Engine = InnoDB default charset = latin1;
    
    prelievo: loop
		fetch PianteSistema into PiantaSingola, DioicaSingola, InfestanteSingolo, SempreverdeSingolo,
								 DimensioneSingola, CostoBaseSingolo, IndiceManutSingolo;
		if (finito = 1) then
			leave prelievo;
        end if;
        
        #GESTIONE DIOICA
        
        #Se la pianta non rispetta la condizione che l'utente ha posto sull'essere dioica, passiamo direttamente alla pianta successiva
        if(@Dioica is not null) then #Il primo if distingue il caso in cui l'utente non ha espresso preferenze
			if(DioicaSingola <> @Dioica) then
				iterate prelievo;
            end if;
        end if;
        
        #GESTIONE INFESTANTE
        
        #Se la pianta non rispetta la condizione che l'utente ha posto sull'essere infestante, passiamo direttamente alla pianta successiva
        if(@Infestante is not null) then #Il primo if distingue il caso in cui l'utente non ha espresso preferenze
			if(InfestanteSingolo <> @Infestante) then
				iterate prelievo;
            end if;
        end if;
			
		#GESTIONE SEMPREVERDE
            
        #Se la pianta non rispetta la condizione che l'utente ha posto sull'essere Sempreverde, passiamo direttamente alla pianta successiva
        if(@Sempreverde is not null) then #Il primo if distingue il caso in cui l'utente non ha espresso preferenze
			if(SempreverdeSingolo <> @Sempreverde) then
				iterate prelievo;
            end if;
        end if;
			
		#GESTIONE DIMENSIONE
            
        #Controlliamo ora se la pianta rientra nella condizione imposta dall'utente sulla dimensione; qui, a seconda del valore inserito si hanno
        #diversi range, influenzati a loro volta dall'importanza assegnata alla dimensione
        case
			
			when @Dimensione is not null and @Dimensione = 'MoltoPiccola' then		#Una pianta è definita 'MoltoPiccola' se non supera i 10 cm di raggio
				if(DimensioneSingola > (0.1 + 0.05 * (10 - @ImpDimensione))) then	#Questa formula è pensata in modo tale da arrivare a prendere le piante
					iterate prelievo;												#fino a 55 cm di raggio (cioè a metà del range delle piante 'Medie')
                end if;																#quando l'importanza è minima, mentre rimane strettamente sotto i 10 cm
																					#quando è massima
                                                                                    
			when @Dimensione is not null and @Dimensione = 'Piccola' then	#Una pianta è definita 'Piccola' se è fra i 10 e i 30 cm di raggio
				if(DimensioneSingola <= (0.1 - 0.01 * (10 - @ImpDimensione)) or
					DimensioneSingola > (0.3 + 0.04 * (10 - @ImpDimensione))) then  #L'idea è simile anche qui, solo che adesso il range si allarga sia verso
					iterate prelievo;												#il basso (verso 'MoltoPiccola') sia verso l'alto (verso 'Media') al calare
				end if;																#dell'importanza (le cifre sono pensate in modo tale da raggiungere al massimo
																					# 0 in basso e 70 (cioè il massimo valore di 'Media' in alto)
			
            when @Dimensione is not null and @Dimensione = 'Media' then	#Una pianta è definita 'Media' se è fra i 30 e i 70 cm di raggio
				if(DimensioneSingola <= (0.3 - 0.02 * (10 - @ImpDimensione))or		#Valore minimo: 10 cm --> Minimo valore di 'Piccola'
					DimensioneSingola > (0.7 + 0.05 * (10 - @ImpDimensione))) then	#Valore massimo: 120 cm --> Massimo valore di 'Grande'
					iterate prelievo;	
				end if;		
                
			when @Dimensione is not null and @Dimensione = 'Grande' then	#Una pianta è definita 'Grande' se è fra i 70 e i 120 cm di raggio
				if(DimensioneSingola <= (0.7 - 0.04 * (10 - @ImpDimensione))or		#Valore minimo: 30 cm --> Minimo valore di 'Media'
					DimensioneSingola > (1.2 + 0.08 * (10 - @ImpDimensione))) then	#Valore massimo: 200 cm --> Valore 80 cm sopra il massimo di 'Grande'
					iterate prelievo;	
				end if;	
                
			when @Dimensione is not null and @Dimensione = 'MoltoGrande' then	#Una pianta è definita 'MoltoGrande' se è sopra i 120cm di raggio
				if(DimensioneSingola <= (1.2 - 0.07 * (10 - @ImpDimensione)))then	#Valore minimo: 50 cm --> Valore a metà di 'Media'
					iterate prelievo;												#Valore massimo: NA
				end if;	
                
			ELSE BEGIN END;  
	
        end case; #Da notare che se l'utente non ha specificato una dimensione il case viene semplicemente ignorato
        
        
        #GESTIONE COSTO
        
        #Controlliamo ora se la pianta rientra nella condizione imposta dall'utente sul costo; in maniera simile a 'Dimensione', si hanno qui
        #diversi range, influenzati a loro volta dall'importanza assegnata al costo
        case
			
			when @Costo is not null and @Costo = 'MoltoEconomica' then		#Un costo è 'Basso' se non supera 15
				if(CostoBaseSingolo > (15 + 3 * (10 - @ImpCosto))) then			#Valore Minimo : NA
					iterate prelievo;											#Valore Massimo: 45 --> Metà di 'Medio'
                end if;																
                                                                                    
			when @Costo is not null and @Costo = 'Economica' then	#Un costo è 'MedioBasso' se è fra 15 e 30
				if(CostoBaseSingolo <= (15 - 1.5 * (10 - @ImpCosto)) or			#Valore Minimo : 0
					CostoBaseSingolo > (30 + 3 * (10 - @ImpCosto))) then 		#Valore Massimo: 60 --> Massimo valore di 'Medio'
					iterate prelievo;												
				end if;																
			
            when @Costo is not null and @Costo = 'NellaMedia' then	#Un costo è 'Medio' se è fra 30 e 60
				if(CostoBaseSingolo <= (30 - 1.5 * (10 - @ImpCosto))or		#Valore minimo: 15 --> Minimo valore di 'Basso'
					CostoBaseSingolo > (60 + 4 * (10 - @ImpCosto))) then	#Valore massimo: 100 --> Massimo valore di 'MedioAlto'
					iterate prelievo;	
				end if;		
                
			when @Costo is not null and @Costo = 'Costosa' then	#Un costo è 'MedioAlto' se è fra 60 e 100
				if(CostoBaseSingolo <= (60 - 3 * (10 - @ImpCosto))or		#Valore minimo: 30 --> Minimo valore di 'Medio'
					CostoBaseSingolo > (100 + 5 * (10 - @ImpCosto))) then	#Valore massimo: 150 --> Valore di 50 sopra il massimo di 'Alto'
					iterate prelievo;	
				end if;	
                
			when @Costo is not null and @Costo = 'MoltoCostosa' then	#Un costo è 'Alto' se è sopra 100
				if(CostoBaseSingolo <= (100 - 5.5 * (10 - @ImpCosto)))then	#Valore minimo: 45 cm --> Valore a metà di 'Medio'
					iterate prelievo;										#Valore massimo: NA
				end if;	
                
			ELSE BEGIN END;  
            
        end case; #Da notare che se l'utente non ha specificato un costo il case viene semplicemente ignorato
        
        
        #GESTIONE INDICE MANUTENZIONE
        
        #Controlliamo ora se la pianta rientra nella condizione imposta dall'utente sulla manutenzione; in maniera simile a 'Dimensione', si hanno qui
        #diversi range, influenzati a loro volta dall'importanza assegnata al costo
        case
			
			when @IndiceManut is not null and @IndiceManut = 'Basso' then	#Un indice è 'Basso' se non supera 3
				if(IndiceManutSingolo > (3 + 0.4 * (10 - @ImpIndiceManut))) then			#Valore Minimo : NA
					iterate prelievo;														#Valore Massimo: 5 --> Minimo di 'Medio'
                end if;															
			
            when  @IndiceManut is not null and @IndiceManut = 'Medio' then		#Un indice è 'Medio' se è fra 3 e 5
				if(IndiceManutSingolo <= (3 - 0.15 * (10 - @ImpIndiceManut))or		#Valore minimo: 1.5 --> Medio valore di 'Basso'
					IndiceManutSingolo > (5 + 0.15 * (10 - @ImpIndiceManut))) then	#Valore massimo: 6.5 --> 1.5 in più del minimo valore di 'Alto'
					iterate prelievo;	
				end if;	
                
			when @IndiceManut is not null and @IndiceManut = 'Alto' then		#Un indice è 'Alto' se è sopra 5
				if(IndiceManutSingolo <= (5 - 0.1 * (10 - @ImpIndiceManut)))then	#Valore minimo: 4 --> Valore a metà di 'Medio'
					iterate prelievo;												#Valore massimo: NA
				end if;
                
			ELSE BEGIN END;  
                
        end case; #Da notare che se l'utente non ha specificato un indice di manutenzione il case viene semplicemente ignorato
        
        
        #GESTIONE ACQUA
        
        #Per l'acqua, il conto si gestisce così:
        # - Se la quantità necessitata è 'Bassa' si prende 1
        # - Se la quantità necessitata è 'Media' si prende 3
        # - Se la quantità necessitata è 'Alta' si prende 5
        # - Questo numero si moltiplica per la periodicità e si può lavorare sui range
        
        set AcquaSingola = (
							select if(A.Quantita = 'Basso', @Quantita := 1,
									if(A.Quantita = 'Medio', @Quantita := 3, @Quantita := 5)) * Periodicita
							from Acqua A inner join Esigenze E
								on A.idAcqua = E.AcquaVegetativo  #Si considerano i periodi vegetativi perché sono quelli che richiedono pià cura
                            where E.Pianta = PiantaSingola
                            );
                            
		#Controlliamo se la pianta rispetta la condizione sull'acqua
        case
			when @Acqua is not null and @Acqua = 'Basso' then			#Una pianta ha un 'Basso' necessità (scusate l'italiano) di acqua se il coefficiente
				if(AcquaSingola > (10 + 0.75 * (10 - @ImpAcqua))) then	#di prima non supera 10
					iterate prelievo;									#Valore minimo: NA
                end if;													#Valore massimo: 17.5 --> Metà di 'Medio'
                
            when @Acqua is not null and @Acqua = 'Medio' then			#Una pianta ha un 'Medio' necessità (scusate di nuovo) di acqua se il coefficiente
				if(AcquaSingola <= (10 - 0.5 * (10 - @ImpAcqua)) or		#di prima è fra 10 e 25
					AcquaSingola > (25 + 1.25 * (10 - @ImpAcqua))) then		#Valore minimo: 5 --> Metà di 'Basso'
					iterate prelievo;										#Valore massimo: 32.5 --> 7.5 sopra del minimo valore di 'Alto'
                end if;
            
            when @Acqua is not null and @Acqua = 'Alto' then			#Una pianta ha un 'Alto' necessità (si vabbe avete capito) di acqua se il coefficiente
				if(AcquaSingola <= (25 - 0.75 * (10 - @ImpAcqua))) then #di prima è fra 10 e 25
					iterate prelievo;										#Valore minimo: 17.5 --> Metà di 'Medio'
                end if;														#Valore massimo: NA
                
			ELSE BEGIN END;  
            
        end case;
										
                                        
		#GESTIONE LUCE
        
        #Per la luce, il conto si gestisce così:
        # - Se la quantità necessitata è 'Bassa' si prende 1
        # - Se la quantità necessitata è 'Media' si prende 3
        # - Se la quantità necessitata è 'Alta' si prende 5
        # - Questo numero si moltiplica per il numero di ore al giorno
        # - Se si necessita che sia diretta, si moltplica x2
        
        set LuceSingola = (
							select if(L.Quantita = 'Bassa', @Quantita := 1,
									if(L.Quantita = 'Media', @Quantita := 3, @Quantita := 5)) * L.NumOre *
                                    if(L.Diretta = 1, 2, 1)
							from Luce L inner join Esigenze E
								on L.idLuce = E.LuceVegetativo  #Si considerano i periodi vegetativi perché sono quelli che richiedono pià cura
                            where E.Pianta = PiantaSingola
                            );
                            
		#Controlliamo se la pianta rispetta la condizione sulla luce
        case
			when @Luce is not null and @Luce = 'Basso' then			#Una pianta ha una 'Bassa' necessità di luce se il coefficiente di prima non
				if(LuceSingola > (20 + 3 * (10 - @ImpLuce))) then	#supera 20
					iterate prelievo;									#Valore minimo: NA
                end if;													#Valore massimo: 50 --> Metà di 'Medio'
                
            when @Luce is not null and @Luce = 'Medio' then			#Una pianta ha una 'Media' necessità di luce se il coefficiente di prima è fra
				if(LuceSingola <= (20 - 1 * (10 - @ImpLuce)) or	#20 e 80
					LuceSingola > (80 + 4 * (10 - @ImpLuce))) then		#Valore minimo: 10 --> Metà di 'Basso'
					iterate prelievo;										#Valore massimo: 120 --> 40 sopra del minimo valore di 'Alto'
                end if;
            
            when @Luce is not null and @Luce = 'Alto' then			#Una pianta ha un 'Alta' necessità di luce se il coefficiente di prima è sopra
				if(LuceSingola <= (80 - 3 * (10 - @ImpLuce))) then #80
					iterate prelievo;										#Valore minimo: 50 --> Metà di 'Medio'
                end if;														#Valore massimo: NA
                
			ELSE BEGIN END;  
            
        end case;
        
        
        #GESTIONE DELLE TEMPERATURE
        
        #Per le temperature, si prende semplicemente la media fra la temperatura max e min e si controllano i range. Qui, tuttavia, quando
        #si allargano i range, si allargano più che altro verso il basso, in quanto le piante sopportano meglio temperature più alte della norma piuttosto
        #che più basse
        
        set TemperaturaSingola = (
							select (TempMax - TempMin)/2
							from Temperatura T inner join Esigenze E
								on T.idTemp = E.Temperatura
                            where E.Pianta = PiantaSingola
                            );
                            
		#Controlliamo se la pianta rispetta la condizione sulla temperatura
        case
			when @Temperatura is not null and @Temperatura = 'MoltoFreddo' then	#Un clima 'MoltoFreddo' ha una media sotto i 7 gradi
				if(TemperaturaSingola > (7 + 0.1 * (10 - @ImpTemperatura))) then
					iterate prelievo;									#Valore minimo: NA
                end if;													#Valore massimo: 8 --> Poco più del valore massimo
                
			when @Temperatura is not null and @Temperatura = 'Freddo' then	#Un clima 'Freddo' ha una media fra i 7 e i 10 gradi
				if(TemperaturaSingola <= (7 - 0.3 * (10 - @ImpTemperatura))or
					TemperaturaSingola > (10 + 0.1 * (10 - @ImpTemperatura))) then	
					iterate prelievo;									#Valore minimo: 4
                end if;													#Valore massimo: 11
                
            when @Temperatura is not null and @Temperatura = 'Medio' then	#Un clima 'Medio' ha una media fra i 10 e i 12 gradi
				if(TemperaturaSingola <= (10 - 0.15 * (10 - @ImpTemperatura)) or
					TemperaturaSingola > (12 + 0.1 * (10 - @ImpTemperatura))) then		#Valore minimo: 8.5
					iterate prelievo;													#Valore massimo: 13
                end if;
            
            when @Temperatura is not null and @Temperatura = 'Caldo' then 	#Un clima 'Caldo' ha una media fra i 12 e i 14 gradi
				if(TemperaturaSingola <= (12 - 0.15 * (10 - @ImpTemperatura)) or
					TemperaturaSingola > (14 + 0.1 * (10 - @ImpTemperatura))) then	 
					iterate prelievo;										#Valore minimo: 10.5
                end if;														#Valore massimo: 15
                
			when @Temperatura is not null and @Temperatura = 'MoltoCaldo' then	#Un clima 'MoltoCaldo' ha una media sopra i 14 gradi
				if(TemperaturaSingola > (14 - 0.1 * (10 - @ImpTemperatura))) then	
					iterate prelievo;									#Valore minimo: 13
                end if;													#Valore massimo: NA
                
			ELSE BEGIN END;  
            
        end case;
        
    #GESTIONE TERRENO
        
        #Per il terreno, controlliamo se è compatibile con la pianta attraverso una valutazione di consistenza, permeabilità, pH ed elementi presenti
        if(@Terreno is not null) then
			set TerrenoSingolo = (
									select Terreno
                                    from Esigenze
                                    where Pianta = PiantaSingola
                                    );
			if (not exists (											#Prima si controlla che vi sia una compatibilità macroscopica fra il terreno
						select *										#in questione e le necessità della pianta
                        from Terreno T1 inner join Terreno T2
							on (T1.Consistenza = T2.Consistenza and
								T1.Permebilita = T2.Permeabilita and
                                T1.pH = T2.pH)
						where T1.idTerreno = TerrenoSingolo and
							T2.idTerreno = @Terreno
                            ))then
				iterate prelievo;
			end if;
			
            #A questo punto verifichiamo se nel terreno in questione c'è almeno il 60% degli elementi necessari alla pianta
            
            #Calcoliamo il numero degli elementi necessitati
            set @NumElementi = (															
									select count(*)
                                    from EsigenzeElemento
                                    where Pianta = PiantaSingola
                                    );
			
            #Calcoliamo gli elementi in comune
			set @ElementiComuni = (
									select count(*)
                                    from EsigenzeElemento
                                    where Pianta = PiantaSingola and
										Elemento not in (
															select Elemento
                                                            from ComposizioneTerreno
                                                            where Terreno = @Terreno
                                                            )
										);
                                        
			#Controlliamo la condizione, con l'aggiunta dell'importanza
			if (@ElementiComuni <= @ImpTerreno/10 * @NumElementi) then
				iterate prelievo;
            end if;
        end if;
        
        #GESTIONE PERIODI
        
        #Per i periodi, la pianta viene scelta se corrisponde per più del 60% alle scelte dell'utente
        if(exists(	#Quest'if è necessario se l'utente non ha specificato preferenze, nel qual caso si creerebbero problemi relativamente alla divisione
					select *
                    from PreferenzePeriodi
                    where Preferenze = _IdPreferenze
                    )) then	
			set @Corrispondenza = (
								select sum(PP.Importanza)
                                from CicliPianta CP inner join PreferenzePeriodi PP
									on CP.Periodo = PP.Periodo
								where CP.Pianta = PiantaSingola and
									PP.Preferenze = _IdPrefenrenze
                                    )/(
										select sum(PP.Importanza)
                                        from PreferenzePeriodi PP
                                        where PP.Preferenze = _IDPreferenze
                                        );
			if @Corrispondenza < 0.6 then
				iterate prelievo;
			end if;
        end if;
        
        #Se la pianta ha superato tutti i test, allora la possiamo inserire fra le piante consigliate
        if(PiantaSingola not in
								(
									select Pianta
                                    from PianteConsigliate
                                    where Preferenze = _IDPreferenze
                                    ))then
			insert into PianteConsigliate values
				(PiantaSingola, _IDPreferenze);
		end if;
    end loop;
    
    select *
    from PianteConsigliate;
    
    drop temporary table PianteConsigliate;
end $$

delimiter ;

