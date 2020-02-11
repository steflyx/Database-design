

#Event che, ogni anno, analizza gli interventi effettuati nel corso dell'anno e, eventualmente, aggiunge nuove necessità alle piante che 
#ne hanno bisogno.
#La gestione di questa parte del database funziona così:
# - Se più del 10% degli utenti che ha acquistato una data pianta ha richiesto un particolare intervento, questo viene inserito fra le necessità
# - Se è stato richiesto fra il 5 e il 10% viene inserito solo se l'intervento rappresenta più della metà delle richieste totali

drop event if exists EventAggiornaNecessita;

delimiter $$

create event EventAggiornaNecessita
on schedule every 1 year
starts '2016-12-31 00:02:00'
do
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare AgenteSingolo int;
    declare ProbabilitaSingola int;
    #questo cursore servirà dopo per aggiornare le piante
    declare PianteSistema cursor for
		select idPianta
        from Pianta;
    
    #------------------------------------------------------------------------------------------------------------------                           
    #		GESTIONE DEI TRATTAMENTI
	#------------------------------------------------------------------------------------------------------------------                           
    
	#La gestione dei trattamenti funziona in maniera diversa: in caso sia stato richiesto un intervento contro un particolare agente
	#su una particolare pianta in più del 10% degli esemplari acquistati, il numero di richieste viene aggiunto alle probabilità di
	#attacco di quell'agente su quella pianta (fino al 50%, per evitare crescite esponenziali incontrollate)
    declare TrattamentiDaAggiungere cursor for
		select E.Pianta,
			T.Agente,
            count(*)/(
						select count(*)
                        from Esemplare E1
                        where E1.Venduto = true and
							E1.Pianta = E.Pianta
                            ) as Probabilita
		from Intervento I inner join Esemplare E
			on I.Esemplare = E.idEsemplare
            inner join Trattamento T
            on I.idIntervento = T.Intervento
		where I.Motivo = 'Richiesta' and
			year(I.Data) = year(current_date()) 
		group by E.Pianta, T.Agente
        having count(*) > 0.1 * (
									select count(*)
									from Esemplare E1
									where E1.Venduto = true and
										E1.Pianta = E.Pianta
                            );
						
	declare continue handler for 
		not found set finito = 1;
    
    open TrattamentiDaAggiungere;
    
    prelievo: loop
		fetch TrattamentiDaAggiungere into PiantaSingola, AgenteSingolo, ProbabilitaSingola;
        if(finito = 1) then
			set finito = 0;
			leave prelievo;
		end if;
        
        #In questo modo si evitano crescite incontrollate della probabilità, ma quest'agente verrà comunque considerato nella creazione
        #degli interventi
        if (ProbabilitaSingola > 50) then
			set ProbabilitaSingola = 51;
        end if;
        
		#Inseriamo le probabilità qualora non ci siano già, altrimenti aggiorniamo la probabilità
		if(not exists(
						select *
						from PeriodoAttacchi
						where Pianta = PiantaSingola and
							Agente = AgenteSingolo
                            ))then
			insert into PeriodoAttacchi (`InizioPeriodo`, `FinePeriodo`, `Probabilita`, `Pianta`, `Agente`) values
				(1, 12, ProbabilitaSingola, PiantaSingola, AgenteSingolo);
		else
			update PeriodoAttacchi
            set Probabilita = Probabilita + ProbabilitaSingola
            where Pianta = PiantaSingola and
				Agente = AgenteSingolo and
                Probabilita < 50;
		end if;
	end loop;
    
    close TrattamentiDaAggiungere;
    
	#------------------------------------------------------------------------------------------------------------------                           
    #		GESTIONE DELLE CONCIMAZIONI
	#------------------------------------------------------------------------------------------------------------------
     
     
	#Si inizia con le concimazioni
	drop temporary table if exists ConcimazioniDaAggiungere;
	create temporary table ConcimazioniDaAggiungere(
		Pianta int not null,
		Concimazione int not null,
        primary key (Pianta, Concimazione)
    )Engine = InnoDB default charset = latin1;
    
    #Per ogni pianta, valutiamo se esistono concimazioni che sono state richieste per più del 10% del totale degli esemplari venduti
    insert into ConcimazioniDaAggiungere
		select E.Pianta,
			ITC.TipoConcimazione
        from Intervento I inner join TipoInterventoConcimazione ITC
			on I.idIntervento = ITC.Intervento
            inner join Esemplare E
            on I.Esemplare = E.idEsemplare
		where I.Motivo = 'Richiesta' and
			year(I.Data) = year(current_date())
        group by E.Pianta, ITC.TipoConcimazione
        having count(*) >= 0.1 * (
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    );
                                    
	#Verifichiamo se esiste una concimazione che è stata richiesta per il 5/10% degli esemplari venduti e che rappresenta da sola più del 50% degli
    #interventi totali su richiesta
	insert into ConcimazioniDaAggiungere
		select E.Pianta,
			ITC.TipoConcimazione
        from Intervento I inner join TipoInterventoConcimazione ITC
			on I.idIntervento = ITC.Intervento
            inner join Esemplare E
            on I.Esemplare = E.idEsemplare
		where I.Motivo = 'Richiesta' and
			year(I.Data) = year(current_date()) 
        group by E.Pianta, ITC.TipoConcimazione
        having count(*) between 0.05 * (
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    )
							and 0.1*(
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    ) and
				count(*) > 0.5*(
								select count(*)
                                from Intervento I1
									inner join Esemplare E1
									on I1.Esemplare = E1.idEsemplare
								where I1.Motivo = 'Richiesta' and
									year(I1.Data) = year(current_date()) and
                                    E.Pianta = E1.Pianta
								);    
                                
	#Inserimento nel database
    
    #Inseriamo le concimazioni che non erano già previste
    insert into EsigenzeConcimazione
		select PDA.Pianta,
			Concimazione
		from ConcimazioniDaAggiungere PDA left outer join EsigenzeConcimazione EC
			on (PDA.Pianta = EC.Pianta and PDA.Concimazione = EC.TipoConcimazione)
        where EC.Pianta is null or
			EC.TipoConcimazione is null;
    
    drop temporary table ConcimazioniDaAggiungere;
    
    #------------------------------------------------------------------------------------------------------------------                           
    #		GESTIONE DELLE POTATURE
    #------------------------------------------------------------------------------------------------------------------
                                
	drop temporary table if exists PotatureDaAggiungere;
    create temporary table PotatureDaAggiungere(
		Pianta int not null,
        Potatura int not null,
        primary key (Pianta, Potatura)
    )Engine = InnoDB default charset = latin1;
    
    #Per ogni pianta, valutiamo se esistono potature che sono state richieste per più del 10% del totale degli esemplari venduti
    insert into PotatureDaAggiungere
		select E.Pianta,
			ITP.TipoPotatura
        from Intervento I inner join TipoInterventoPotatura ITP
			on I.idIntervento = ITP.Intervento
            inner join Esemplare E
            on I.Esemplare = E.idEsemplare
		where I.Motivo = 'Richiesta' and
			year(I.Data) = year(current_date())
        group by E.Pianta, ITP.TipoPotatura
        having count(*) >= 0.1 * (
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    );
								
    #Verifichiamo se esiste una potatura che è stata richiesta per il 5/10% degli esemplari venduti e che rappresenta più del 50% degli interventi su
    #richiesta
	insert into PotatureDaAggiungere
		select E.Pianta,
			ITP.TipoPotatura
        from Intervento I inner join TipoInterventoPotatura ITP
			on I.idIntervento = ITP.Intervento
            inner join Esemplare E
            on I.Esemplare = E.idEsemplare
		where I.Motivo = 'Richiesta' and
			year(I.Data) = year(current_date()) 
        group by E.Pianta, ITP.TipoPotatura
        having count(*) between 0.05 * (
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    )
							and 0.1*(
									select count(*)
									from Esemplare E1
                                    where E.Pianta = E1.Pianta and
										E1.venduto = true
                                    ) and
				count(*) > 0.5*(
								select count(*)
                                from Intervento I1
									inner join Esemplare E1
									on I1.Esemplare = E1.idEsemplare
								where I1.Motivo = 'Richiesta' and
									year(I1.Data) = year(current_date()) and
                                    E.Pianta = E1.Pianta
								);          
                                
	#Inserimento nel database
    
    #Inseriamo le potature che non erano già previste
    insert into NecessitaPotatura
		select 1,
			Potatura,
			PDA.Pianta
		from PotatureDaAggiungere PDA left outer join NecessitaPotatura NP
			on (PDA.Pianta = NP.Pianta and PDA.Potatura = NP.TipoPotatura)
        where NP.Pianta is null or
			NP.TipoPotatura is null;
            
	#Aggiorniamo quelle che erano già presenti
    update NecessitaPotatura NP inner join PotatureDaAggiungere PDA
		on (PDA.Pianta = NP.Pianta and PDA.Potatura = NP.TipoPotatura)
	set NP.Quantita = NP.Quantita + 1;
    
    drop temporary table PotatureDaAggiungere;
    
    #------------------------------------------------------------------------------
    #	AGGIORNAMENTO INDICI DI MANUTENZIONE
    #------------------------------------------------------------------------------
    
	#Aggiornati tutte le esigenze e necessità, andiamo ad aggiornare l'indice di manutenzione di tutte le piante
	open PianteSistema;
   
	prelievo1: loop
		fetch PianteSistema into PiantaSingola;
		if (finito = 1) then
			leave prelievo1;
		end if;
        
        #Ricalcoliamo l'indice di manutenzione
        set @IndiceManutenzione = FunctionCalcoloIndiceManutenzione(PiantaSingola);
        
        #Aggiorniamo la tabella "Pianta"
        update Pianta
        set IndiceManut = @IndiceManutenzione
        where idPianta = PiantaSingola;
	end loop;
   
   close PianteSistema;
end $$

delimiter ;

#Event che, una volta all'anno, calcola quali sono le condizioni favorevoli per gli agenti basandosi sui dati delle misurazioni nelle serre
#Per farlo, si segue questo procedimento:
# - Si prende la situazione di ogni condizione (illuminazione, idratazione, ecc) nella settimana precedente l'insorgenza della patologia (per il database,
#   dal momento in cui è stata individuata con un report di diagnostica)
# - Si controlla se, per ogni particolare condizione, l'occorrenza di malattie a essa associata è superiore del 10% alla media generale

drop event if exists EventCalcoloCondizioniFavorevoli;

delimiter $$

create event EventCalcoloCondizioniFavorevoli
on schedule every 1 year
starts '2016-12-31 20:00:00'
do
begin
	declare finito int default 0;
    declare ReportConsiderati cursor for
		select *
        from ReportDiagnostica
        where year(Data) = year(current_date());
	
    declare continue handler for
		not found set finito = 1;
	
    #Si creano due temporary table di supporto
    drop table if exists MisurazioniMedie;
    create table if not exists MisurazioniMedie(
		idMisurazione int auto_increment,
        Agente int not null,
        Data date,
        Idratazione varchar(45),
        pH varchar(45),
        Umidita int,
        Temperatura int,
        Illuminazione varchar(45),
		primary key(idMisurazione)
    )Engine = InnoDB default charset = latin1;
    
    
     drop table if exists MisurazioniMedieElementi;
    create table MisurazioniMedieElementi(
		idMisurazione int auto_increment,
        Agente int,
        Elemento int,
        Concentrazione int,
        primary key (idMisurazione)
    )Engine = InnoDB default charset = latin1;
    
    #----------------------------------------------------------------------------------------------------------------------------------
    #		RECUPERO VALORI
    #----------------------------------------------------------------------------------------------------------------------------------
    
    #Recuperiamo, per ogni report, le varie misurazioni nella settimana precedente e l'agente che è stato diagnosticato per ultimo
    insert into MisurazioniMedie (`Agente`, `Data`, `Idratazione`, `pH`, `Umidita`, `Temperatura`, `Illuminazione`)
		select DE.Agente,
			RD.Data,
            MC.Idratazione,
            MC.pH,
            MA.Umidita,
            MA.Temperatura,
            MA.Illuminazione
        from ReportDiagnostica RD inner join DiagnosiEsperto DE
			on (RD.Data = DE.DataReport and 
				RD.Esemplare = DE.Esemplare)
			inner join MisurazioneAmbientale MA
            on RD.Sezione = MA.Sezione
			inner join Contenitore C
            on RD.Esemplare = C.Esemplare
            inner join MisurazioneContenitore MC
            on C.idContenitore = MC.Contenitore
		where date(MA.Timestamp) > RD.Data - interval 7 day and
			date(MC.Timestamp) > RD.Data - interval 7 day and
            DE.Numero >= all (
								select DE1.Numero
                                from ReportDiagnostica RD1 inner join DiagnosiEsperto DE1
									on (RD1.Data = DE1.DataReport and 
										RD1.Esemplare = DE1.Esemplare)
								);
	
    #Aggiungiamo anche le misurazioni delle concentrazioni degli elementi
	insert into MisurazioniMedieElementi (`Agente`, `Elemento`, `Concentrazione`)
		select DE.Agente,
			PE.Elemento,
            PE.Quantita
        from ReportDiagnostica RD inner join Contenitore C
			on RD.Esemplare = C.Esemplare
            inner join MisurazioneContenitore MC
            on (C.idContenitore = MC.Contenitore and
				date(MC.TimeStamp) = RD.Data)
			inner join PresenzaElemento PE
            on (MC.Timestamp = PE.TimeStampMisurazione and
				MC.Contenitore = PE.Contenitore)
			inner join DiagnosiEsperto DE
            on (RD.Data = DE.DataReport and 
				RD.Esemplare = DE.Esemplare)
		where date(MC.TimeStamp) > RD.Data - interval 7 day and
            DE.Numero >= all (
								select DE1.Numero
                                from ReportDiagnostica RD1 inner join DiagnosiEsperto DE1
									on (RD1.Data = DE1.DataReport and 
										RD1.Esemplare = DE1.Esemplare)
								);
	
    #----------------------------------------------------------------------------------------------------------------------------------
    #		CALCOLO CONDIZIONI FAVOREVOLI SINGOLE
    #----------------------------------------------------------------------------------------------------------------------------------
    
    #Temporary table di supporto per memorizzare i valori di 'Idratazione' favorevoli all'agente
    create temporary table if not exists IdratazioneFavorevole(
		Agente int,
        Idratazione varchar(45),
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into IdratazioneFavorevole (`Agente`, `Idratazione`, `Posizione`)
		select MM.Agente,
			MM.Idratazione,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select Agente,
					Idratazione,
                    count(*) as NumOccorrenze
				from MisurazioniMedie
                group by Agente, Idratazione
                ) as D
			on (MM.Agente = D.Agente and
				MM.Idratazione = D.Idratazione),
			(select @RowNumber := 0) as N
        group by Agente, Idratazione
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie
											group by Agente, Idratazione
										) as D1
                                    )
		order by D.NumOccorrenze DESC;
	
	#Temporary table di supporto per memorizzare i valori di 'pH' favorevoli all'agente
    create temporary table if not exists pHFavorevole(
		Agente int,
        pH varchar(45),
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into pHFavorevole (`Agente`, `pH`, `Posizione`)
		select MM.Agente,
			MM.pH,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select Agente,
					pH,
                    count(*) as NumOccorrenze
				from MisurazioniMedie
                group by Agente, Idratazione
                ) as D
			on (MM.Agente = D.Agente and
				MM.pH = D.pH),
			(select @RowNumber := 0) as N
        group by Agente, pH
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie
											group by Agente, pH
										) as D1
									)
		order by D.NumOccorrenze DESC;
        
	#Temporary table di supporto per memorizzare i valori di 'Umidita' favorevoli all'agente
    create temporary table UmiditaFavorevole(
		Agente int,
        Umidita int,
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into UmiditaFavorevole (`Agente`, `Umidita`, `Posizione`)
		select MM.Agente,
			MM.Umidita,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select Agente,
					Umidita,
                    count(*) as NumOccorrenze
				from MisurazioniMedie
                group by Agente, Umidita
                ) as D
			on (MM.Agente = D.Agente and
				MM.Umidita = D.Umidita),
			(select @RowNumber := 0) as N
        group by Agente, Umidita
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie
											group by Agente, Umidita
										) as D1
									)
		order by D.NumOccorrenze DESC;
        
	#Temporary table di supporto per memorizzare i valori di 'Temperatura' favorevoli all'agente
    create temporary table TemperaturaFavorevole(
		Agente int,
        Temperatura varchar(45),
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into TemperaturaFavorevole (`Agente`, `Temperatura`, `Posizione`)
		select MM.Agente,
			MM.Temperatura,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select Agente,
					Temperatura,
                    count(*) as NumOccorrenze
				from MisurazioniMedie
                group by Agente, Temperatura
                ) as D
			on (MM.Agente = D.Agente and
				MM.Temperatura = D.Temperatura),
			(select @RowNumber := 0) as N
        group by MM.Agente, MM.Temperatura
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie
											group by Agente, Temperatura
										) as D1
									)
		order by D.NumOccorrenze DESC;
        
	#Temporary table di supporto per memorizzare i valori di 'Illuminazione' favorevoli all'agente
    create temporary table IlluminazioneFavorevole(
		Agente int,
        Illuminazione varchar(45),
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into IlluminazioneFavorevole (`Agente`, `Illuminazione`, `Posizione`)
		select Agente,
			Illuminazione,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select Agente,
					Illuminazione,
                    count(*) as NumOccorrenze
				from MisurazioniMedie
                group by Agente, Illuminazione
                ) as D
			on (MM.Agente = D.Agente and
				MM.Illuminazione = D.Illuminazione),
			(select @RowNumber := 0) as N
        group by Agente, Illuminazione
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie
											group by Agente, Illuminazione
										) as D1
									)
		order by D.NumOccorrenze DESC;
        
	
	#Temporary table di supporto per memorizzare i valori dei mesi favorevoli all'agente
    create temporary table MeseFavorevole(
		Agente int,
        Mese varchar(45),
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into MeseFavorevole (`Agente`, `Mese`, `Posizione`)
		select Agente,
			Mese,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedie MM inner join 
			(
				select MM.Agente,
					M.Mese,
                    count(*) as NumOccorrenze
				from MisurazioniMedie MM inner join 
					(
						select distinct month(Data) as Mese,
							Agente
                        from MisurazioniMedie
                        ) as M
					on (MM.Agente = M.Agente and
						month(MM.Data) = M.Mese)
                group by Agente, Mese
                ) as D
			on (MM.Agente = D.Agente and
				month(MM.Data) = D.Illuminazione),
			(select @RowNumber := 0) as N
        group by Agente, Mese
        having count(*) > 1.1 * (
									select avg(NumCasi)
                                    from (
											select count(*) as NumCasi
											from MisurazioniMedie MM1 inner join 
												(
													select distinct month(Data) as Mese,
														Agente
													from MisurazioniMedie
												) as M1
												on (MM1.Agente = M1.Agente and
													month(MM1.Data) = M1.Mese)
											group by Agente, Mese
											) as D1
                                    ) 
		order by D.NumOccorrenze DESC;
        
        
    #Temporary table di supporto per memorizzare i valori degli 'Elementi' favorevoli all'agente
    create temporary table if not exists ElementoFavorevole(
		Agente int,
        Elemento int,
		Posizione int,
        primary key(Agente)
    )Engine = InnoDB default charset = latin1;
    
    insert into ElementoFavorevole (`Agente`, `Elemento`, `Posizione`)
		select Agente,
			Elemento,
            @RowNumber = @RowNumber + 1
        from MisurazioniMedieElementi MME inner join 
			(
				select Agente,
					Elemento,
                    sum(Concentrazione) as TotConcentrazione
				from MisurazioniMedieElementi
                group by Agente, Elemento
                ) as D
			on (MME.Agente = D.Agente and
				MME.Elemento = D.Elemento),
			(select @RowNumber := 0) as N
        group by MME.Agente, MME.Elemento
        having sum(Concentrazione) > 1.1 * (
												select avg(ConcentrazioniSingole)
												from (
														select sum(Concentrazione) as ConcentrazioniSingole
														from MisurazioniMedieElementi
														group by Agente, Elemento
													) as D1
											)
		order by TotConcentrazione DESC;
        
        
        #-----------------------------------------------------------------------------------------------------------------
        #		INSERIMENTO NELLA TABELLA "CONDIZIONI FAVOREVOLI"
        #-----------------------------------------------------------------------------------------------------------------
		
        #Nella tabella "CondizioniFavorevoli" verranno inserite le singole condizioni favorevoli accomunate dallo stesso agente
        #e dalla stessa posizione in classifica
        insert into CondizioniFavorevoli (`Agente`, `Idratazione`, `pH`, `Umidita`, `Temperatura`, `Illuminazione`, `Mese`)
			select A.idAgente,
				IDF.Idratazione,
                PF.pH,
                UF.Umidita,
                TF.Temperatura,
                ILF.Illuminazione,
                MF.Mese
            from Agente A left outer join 
				IdratazioneFavorevole IDF 
					on A.idAgente = IDF.Agente
				left outer join 
				pHFavorevole PF
					on A.idAgente = PF.Agente
				left outer join 
				UmiditaFavorevole UF
					on A.idAgente = UF.Agente
				left outer join 
				TemperaturaFavorevole TF
					on A.idAgente = TF.Agente
				left outer join 
				IlluminazioneFavorevole ILF
					on A.idAgente = ILF.Agente
				left outer join 
				MeseFavorevole MF
					on A.idAgente = MF.Agente
			order by IDF.Posizione, PF.Posizione, UF.Posizione, TF.Posizione, ILF.Posizione, MF.Posizione ASC;
            
		#Infine popoliamo la tabella sulle condizioni favorevoli riguardanti gli elementi
        insert into ElementiCoinvolti (`Agente`, `Elemento`)
			select Agente,
				Elemento
			from ElementoFavorevole;
end $$

delimiter ;

drop event if exists EventCalcoloDiagnosiPossibili;

delimiter $$

create event EventCalcoloDiagnosiPossibili
on SCHEDULE every 1 day
STARTS '2016-07-01 00:00:01'
do 
begin

	declare finito int default 0;
    declare EsemplareSingolo int;
    declare TimestampSingolo timestamp;
    declare SezioneSingola int;
	declare ReportGiornate cursor for
		select Esemplare,
			TimestampMisurazione,
            Sezione
		from ReportDiagnostica
        where Data = current_date() - interval 1 day;
        
	declare continue handler for
		not found set finito = 1;
        
	open ReportGiornate;
        
	prelievo: loop
		fetch ReportGiornate into EsemplareSingolo, TimestampSingolo, SezioneSingola;
        if(finito = 1) then
			leave prelievo;
        end if;
        
        #Segnaliamo che l'esemplare si è ammalato
        update Esemplare
        set Malato = true
        where idEsemplare = EsemplareSingolo;
        
        #Individuiamo le tre patologie (eventualmente con pari merito) che presentano più sintomi in comune
        #con quelli individuati dal report di diagnostica e inseriamole all'interno della tabella "DiagnosiPossibili"
        set @rowNumber = 1;
        insert into DiagnosiPossibili (`Attinenza`, `DataReport`, `Esemplare`, `Agente`)
			select Ranking,
				(current_date() - interval 1 day),
                EsemplareSingolo,
                Agente
			from (
					select D.Agente,
						if(@Sintomi = SintomiComuni, @rowNumber, (@rowNumber := @rowNumber + 1 + least(0, @Sintomi := SintomiComuni))) as Ranking
					from
						(
							select count(*) as SintomiComuni,
								S.Agente
							from InfoSintomi I
								inner join Sintomatologia S
								on I.Sintomo = S.Sintomo
							group by S.Agente
                            having count(*) > 0 #Così si evita di prendere patologie che non hanno sintomi in comune nel caso in cui ne manchino
						) as D
					order by SintomiComuni ASC
					) as D1
			where Ranking <= 3;
            
		#Individuiamo la sezione di isolamento in cui spostare l'esemplare e controlliamo che non sia piena
        set @SerraEsemplare = (
								select idSerra
                                from Serra S inner join Sezione SE
									on S.idSerra = SE.Serra
                                    inner join Ripiano R
									on SE.idSezione = R.Sezione
                                    inner join Contenitore C
                                    on C.Ripiano = R.idRipiano
								where C.Esemplare = EsemplareSingolo
                                );
		set @SezioneInCuiSpostare = (
										select SI.Sezione								
                                        from SezioniIsolamento SI 
                                        where SI.Serra = @SerraEsemplare
                                        );
		set @SpazioRimasto = (
								select MaxPiante - NumPiante
                                from Sezione
                                where CodSezione = @SezioneInCuiSpostare
                                );
		if(@SezioneInCuiSpostare is null or @SpazioRimasto = 0) then
			set @MessaggioErrore = 'ATTENZIONE: Nella serra numero ';
            set @MessaggioErrore = concat(@MessaggioErrore, @SerraEsemplare);
            set @MessaggioErrore = concat(@MessaggioErrore, ' c è un problema con la sezione dedicata alla quarantena');
            signal sqlstate "45000"
            set message_text = @MessaggioErrore;
        end if;
        #Scegliamo il ripiano in cui posizionare l'esemplare
        set @RipianoPiuLibero = (
									select idRipiano
                                    from Ripiano
                                    where Sezione = @SezioneInCuiSpostare and
										(MaxPiante - NumPiante) <= all(
																		select (MaxPiante - NumPiante)
                                                                        from Ripiano
                                                                        where Sezione = @SezioneInCuiSpostare
                                                                        )
                                    );
		#Aggiorniamo la posizione del contenitore
		update Contenitore
        set Ripiano = @RipianoPiuLibero
        where Esemplare = EsemplareSingolo;
                
        #Inseriamo infine l'esemplare in isolamento
        insert into Isolamento values
			(EsemplareSingolo, @SezioneInCuiSpostare);
    end loop;

end $$

delimiter ;



#Event che gestisce gli interventi da fare ogni giorno, valutando se è possibile aggregarne qualcuno.
#La politica di gestione degli interventi si basa sulla stima di 250 dipendenti divisi in 50 sezioni sul territorio
#(rappresentate nel database dai dati nell'attributo "Citta" di "Account").
#La tecnica di gestione funziona nel seguente modo:
# - Si considerano solo gli interventi da effettuare entro al più 15 giorni.
# - Si assegnano 15 punti agli interventi che devono essere fatti entro oggi; per gli altri si toglie 1 punto per ogni
#   giorno in avanti mentre se ne aggiungono 3 per ogni giorno indietro
# - Gli interventi su richiesta guadagnano 5 punti
# - Se in questo lasso di tempo ci sono due o più interventi da effettuare presso uno stesso utente, questi guadagnano
#   tutti il punteggio del più alto più 10 punti ulteriori
# - Si stila una classifica per città, aggiungendo interventi finché l'entità totale non raggiunge 100 (si stima che un 
#   addetto possa fare al più interventi per un'entità totale di 20)
# - Se in una città restano più di 20 punti, questi vengono assegnati alla città che ha più interventi da fare non inseriti
#   fra quelli previsti per la giornata

drop procedure if exists ProcedureCalcoloInterventiGiornalieri;
drop event if exists EventCalcoloInterventiGiornalieri;


drop table if exists InterventiInGiornata;

#Tabella in cui vengono inseriti gli interventi da effettuare nella giornata di oggi
create table InterventiInGiornata(
	Intervento int not null,
	Citta varchar(45),
    Entita int,
    Posizione int,
    primary key (Intervento)
)Engine = InnoDB default charset = latin1;


delimiter $$

create event EventCalcoloInterventiGiornalieri
on schedule every 1 day
starts '2016-06-15 02:00:00'
do
begin
	#Temporary table di appoggio in cui vengono inseriti tutti gli interventi previsti per i prossimi 15 giorni
    drop table if exists InterventiPrevisti;
    create table InterventiPrevisti(
		Intervento int not null,
		Account int,
        Citta varchar(45),
        Entita int,
        Punteggio int,
        primary key (Intervento)
    )Engine = InnoDB default charset = latin1;
    
    #Recuperiamo le informazioni che ci interessano sugli interventi e in più inizializziamo il punteggio
    insert into InterventiPrevisti
		select I.idIntervento,
			A.idAccount,
            A.Citta,
            if(I.Entita is null, 1, I.Entita),
            if(I.Data >= current_date, 15 - datediff(current_date(), I.Data), 3*datediff(I.Data, current_date()))
            + if(I.Motivo = 'Richiesta', 5, 0)
        from Intervento I inner join Scheda S
			on I.Esemplare = S.Esemplare
            inner join Account A
            on S.Account = A.idAccount
		where I.Data < current_date() + interval 15 day and
			I.Effettuato = 0 and
            (I.Motivo = 'Programmato' or
            I.Motivo = 'Richiesta');
            
	call ProcedureCalcoloInterventiGiornalieri();
end $$

create procedure ProcedureCalcoloInterventiGiornalieri()
begin
	declare InterventoSingolo int;
    declare AccountSingolo int;
    declare PunteggioSingolo int;
	declare finito int default 0;
	declare InterventiDaAggiornare cursor for
		select Intervento,
			Account,
            Punteggio
		from InterventiPrevisti;
	declare continue handler for
		not found set finito = 1;
	
	open InterventiDaAggiornare;
    
    prelievo: loop
		fetch InterventiDaAggiornare into InterventoSingolo, AccountSingolo, PunteggioSingolo;
        if (finito = 1) then
			leave prelievo;
        end if;
		#Controlliamo se ci sono due o più interventi presso lo stesso utente fra quelli appena selezionati e, in caso, aggiorniamo il punteggio
        set @MaxPunteggio = (
								select max(Punteggio)
                                from InterventiPrevisti
                                where Account = AccountSingolo);
                                
		update InterventiPrevisti
        set Punteggio = 10 + @MaxPunteggio
        where Intervento = InterventoSingolo;
    end loop;
    
    close InterventiDaAggiornare;
    
    set @Entita = 0;
    
    #Effettuiamo un ranking in base al punteggio (considerando gli interventi per città) e andiamo ad inserire nella materialized view
    insert into InterventiInGiornata
		select D.Intervento,
			D.Citta,
            @Entita,
            D.Ranking
        from (
				select Intervento,
					Citta,
					Entita,
					if(@Citta = Citta, @rank:=@rank +1, @rank:= 1 + least(0, @Citta := Citta)) as Ranking, #Questo if ci dà il ranking per città
					if(@Citta = Citta, @Entita:=@Entita + Entita, @Entita:= Entita + least(0, @Citta := Citta)) as EntitaTot #Questo if calcola l'entità
																															 #totale progressivamente
				from InterventiPrevisti,
					(select @Citta := '') as N
                order by Citta, Punteggio DESC
        ) as D
        where @Entita < 100 or @Entita is null;
        
	#Nel caso in cui esista una città in cui non abbiamo assegnato tutti i lavori, distribuiamo i punti su quella con più interventi esclusi
    set @CittaNonComplete = (
								select count(*)
                                from InterventiInGiornata
                                group by Citta
                                having sum(Entita) < 80
                                );
                                
	if(@CittaNonComplete > 0) then
			set @Entita = 0;
			set @Rank = 0;
           
           #Cerchiamo la città definita sopra
           set @CittaScelta = (
								select Citta
                                from InterventiPrevisti
                                where Intervento not in
														(
															select Intervento
                                                            from InterventiInGiornata
                                                            )
                                group by Citta
                                having count(*) >= all (
															select count(*)
															from InterventiPrevisti
                                                            where Intervento not in
																					(
																						select Intervento
																						from InterventiInGiornata
																					)
															group by Citta
														)
								limit 1
							);
			
            #Calcoliamo i punti avanzati
            set @PuntiAvanzati = (
									select 100*count(*)	#Qui calcoliamo i punti avanzati in totale (si prende in considerazione il caso in 					
												- (		#cui più di una città può non aver usato tutti i punti)
													select sum(D.EntitaSingolaCitta) 
													from (
															select sum(Entita) as EntitaSingolaCitta
															from InterventiInGiornata I1
															group by Citta
                                                            having sum(Entita) < 80
														) as D
													)
									from InterventiInGiornata I
                                    group by Citta
                                    having sum(Entita) < 80
                                    );
            
			#Individuiamo qual è la posizione da cui andremo ad inserire
			set @RankMax = (
							select max(Ranking)
							from InterventiInGiornata
							where Citta = @CittaScelta
						);
           
           
			#Inseriamo gli interventi per la città scelta
			insert into InterventiInGiornata
			select D.Intervento,
				@CittaScelta,
				D.Entita,
				D.Ranking + @RankMax
			from (
					select Intervento,
						Citta,
						Entita,
						@Rank:= @Rank + 1, #Prendiamo il ranking nella città
						@Entita = @Entita + Entita as EntitaTot #Questo if calcola l'entità totale progressivamente
					from InterventiPrevisti
					where Intervento not in (
												select Intervento			#Escludiamo qui gli interventi già inseriti
												from InterventoInGiornata
										)
						and Citta = @CittaScelta
					order by Punteggio DESC
				) as D
			where D.EntitaTot < @PuntiAvanzati;
	
    end if;
end $$

delimiter ;

#Event con cui si verifica che a ogni esemplare in azienda sia associato un contenitore (si suppone infatti che
#sia possibile cancellare i record relativi a contenitori associati ad esemplari venduti)
drop event if exists EventControlloContenitoreEsemplare;

delimiter $$

create event EventControlloContenitoreEsemplare
on schedule every 2 day
starts '2016-06-10 00:03:00'
do
begin
	declare Messaggio varchar(20000) default 'ATTENZIONE: ai seguenti esemplari non è stato associato alcun contenitore: ';
    declare EsemplareTarget int;
    declare primo int default 0;
	#Individuiamo gli esemplari in questione
	declare finito int default 0;
	declare EsemplariSenzaContenitore cursor for
		select idEsemplare
        from Esemplare
        where Venduto = false and
			idEsemplare not in
								(
									select Esemplare
                                    from Contenitore
                                    );
	#Per ognuno di questi esemplari aggiorniamo il messsaggio d'errore
    declare continue handler
		for not found set finito = 1;
	prelievo: loop
		fetch EsemplariSenzaContenitore into EsemplareTarget;
		if(finito = 1) then
			leave prelievo;
		end if;
        #Con questo if ci si assicura un output corretto dal punto di vista grammaticale
        if(primo <> 0)then
			set Messaggio = concat(Messaggio, ', ');
		end if;
        set Messaggio = concat(Messaggio, EsemplareTarget);
        set primo = 1;
    end loop;    
	#Se primo è diverso da 1, vuol dire che il cursore è vuoto; ciò vuol dire che a tutti gli esemplari in azienda è associato un
    #contenitore, pertanto non c'è alcuna condizione d'errore
    if(primo = 1) then
		signal sqlstate "45000"
        set message_text = Messaggio;
    end if;
end $$

delimiter ;

#Event che controlla che, per ogni pianta, i cicli di quella pianta coprano tutto l'anno; se ciò non vale per qualche pianta, manda un messaggio di errore
drop event if exists ControlloCoperturaCicliPiantaEvent;

delimiter $$

create event ControlloCoperturaCicliPiantaEvent
on schedule every 1 day
starts '2016-06-09 00:00:01'
do
begin
	#Calcolo le piante per cui non abbiamo l'informazione completa
	declare Messaggio varchar(1000) default 'ATTENZIONE: Non esiste una documentazione completa riguardo i periodi di vita delle seguenti piante: ';
    declare MessaggioTemp varchar(50);
    declare Primo int default 0;
    declare finito int default 0;
    declare PianteDaAggiornare cursor for
		#Vogliamo le piante per cui la somma dei periodi non sia 12 (quindi non coprono tutto l'anno)
        select Nome
        from Pianta P1
        where 12 <> (
						select 
								sum((P.FinePeriodo - P.InizioPeriodo + 1)) as intervallo,
								C.Pianta
						from 
								PeriodoCicli P inner join CicliPianta C
									on P.idPeriodo = C.Periodo
						where 
								C.Pianta = P1.idPianta
					);
                
	declare continue handler 
		for not found set finito = 1;
    
    open PianteDaAggiornare;
	
    #Per ogni pianta aggiorniamo il messaggio d'errore
    prelievo: LOOP
		fetch PianteDaAggiornare into MessaggioTemp;
        if finito = 1 then
			leave prelievo;
		end if;
		if Primo = 1 then
			set Messaggio = concat(Messaggio, ', ');
		end if;
        set Messaggio = concat(Messaggio, MessaggioTemp);
        set Primo = 1;
    end loop prelievo;
    
    close PianteDaAggiornare;
    
    #Se esiste una pianta da aggiornare, il database segnala il problema
    if(Primo = 1) then
		signal sqlstate "45000"
		set message_text = Messaggio;
	end if;
end $$

delimiter ;

#Event che, una volta al mese, controlla la correttezza delle informazioni presenti in "EsigenzeElemento". Essendo questa una ridondanza, si deve
#avere che le informazioni in essa presenti siano coerenti con quelle ricavabili attraverso "Terreno" in "Esigenze"

drop event if exists EventControlloValiditaEsigenzeElemento;

delimiter $$

create event EventControlloValiditaEsigenzeElemento
on schedule every 1 month
starts '2016-07-15 22:00:00'
do
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare ElementoSingolo int;
    declare ConcentrazioneSingola double;
    declare Elementi cursor for
		select Pianta,
			Elemento,
            Concentrazione
		from EsigenzeElemento;
	declare continue handler for
		not found set finito = 1;
        
	open Elementi;
    
    prelievo: loop
		fetch Elementi into PiantaSingola, ElementoSingolo, ConcentrazioneSingola;
        if(finito = 1)then
			leave prelievo;
        end if;
        
        if(not exists(
						select *
                        from ComposizioneTerreno CT inner join Esigenze E
							on CT.Terreno = E.Terreno
						where E.Pianta = PiantaSingola and
							CT.Elemento = ElementoSingolo and
                            CT.Concentrazione = ConcentrazioneSingola
                            )) then
			set @Messaggio = 'ATTENZIONE: Le informazioni presenti in "EsigenzeElemento" non corrispondono a quell presenti in "ComposizioneTerreno" per la pianta ';
            set @Messaggio = concat(@Messaggio, PiantaSingola);
			signal sqlstate "45000"
            set message_text = @Messaggio;
		end if;
						
    end loop;
    
    close Elementi;
end $$

delimiter ;

#Event che alla fine di ogni giornata valuta tutti i report di diagnostica e calcola le diagnosi possibili più probabile in base ai sintomi
#individuati. Una patologia è considerata tanto più probabile quanti più sintomi ha in comune con quelli individuati; in più, sposta gli esemplari
#in questione nelle sezioni di isolamento apposite

drop event if exists EventGestioneMalattia;

delimiter $$

create event EventGestioneMalattia
on schedule every 1 day
starts '2016-07-01 00:00:01'
do
begin
	declare finito int default 0;
    declare EsemplareSingolo int;
    declare TimestampSingolo timestamp;
    declare SezioneSingola int;
	declare ReportGiornate cursor for
		select Esemplare,
			Timestamp,
            Sezione
		from ReportDiagnostica
        where Data = current_date() - interval 1 day;
        
	declare continue handler for
		not found set finito = 1;
        
	prelievo: loop
		fetch ReportGiornate into EsemplareSingolo, TimestampSingolo, SezioneSingola;
        if(finito = 1) then
			leave prelievo;
        end if;
        
        #Segnaliamo che l'esemplare si è ammalato
        update Esemplare
        set Malato = true
        where idEsemplare = EsemplareSingolo;
        
        #Individuiamo le tre patologie (eventualmente con pari merito) che presentano più sintomi in comune
        #con quelli individuati dal report di diagnostica e inseriamole all'interno della tabella "DiagnosiPossibili"
        set @rowNumber = 1;
        insert into DiagnosiPossibili 
			select Ranking,
				date(TimestampSingolo),
                EsemplareSingolo,
                Agente
			from (
					select D.Agente,
						if(@Sintomi = SintomiComuni, @rowNumber, (@rowNumber := @rowNumber + 1 + least(0, @Sintomi := SintomiComuni))) as Ranking
					from
						(
							select count(*) as SintomiComuni,
								SI.Agente
							from InfoSintomi I
								inner join Sintomatologia S
								on S.Codice = S.Sintomo
							group by S.Agente
                            having count(*) > 0 #Così si evita di prendere patologie che non hanno sintomi in comune nel caso in cui ne manchino
						) as D
					order by SintomiComuni ASC
					) as D1
			where Ranking <= 3;
            
		#Individuiamo la sezione di isolamento in cui spostare l'esemplare e controlliamo che non sia piena
        set @SerraEsemplare = (
								select CodSerra
                                from Serra S inner join Sezione SE
									on S.CodSerra = SE.Serra
                                    inner join Ripiano R
									on SE.CodSezione = R.Sezione
                                    inner join Contenitore C
                                    on C.Ripiano = R.CodRipiano
								where C.Esemplare = EsemplareSingolo
                                );
		set @SezioneInCuiSpostare = (
										select SI.Sezione								
                                        from SezioniIsolamento SI 
                                        where SI.Serra = @SerraEsemplare
                                        );
		set @SpazioRimasto = (
								select MaxPiante - NumPiante
                                from Sezione
                                where CodSezione = @SezioneInCuiSpostare
                                );
		if(@SezioneInCuiSpostare is null or @SpazioRimasto = 0) then
			set @MessaggioErrore = 'ATTENZIONE: Nella serra numero ';
            set @MessaggioErrore = concat(@MessaggioErrore, @SerraEsemplare);
            set @MessaggioErrore = concat(@MessaggioErrore, ' c è un problema con la sezione dedicata alla quarantena');
            signal sqlstate "45000"
            set message_text = @MessaggioErrore;
        end if;
        #Scegliamo il ripiano in cui posizionare l'esemplare
        set @RipianoPiuLibero = (
									select CodRipiano
                                    from Ripiano
                                    where Sezione = @SezioneInCuiSpostare and
										(MaxPiante - NumPiante) <= all(
																		select (MaxPiante - NumPiante)
                                                                        from Ripiano
                                                                        where Sezione = @SezioneInCuiSpostare
                                                                        )
                                    );
		#Aggiorniamo la posizione del contenitore
		update Contenitore
        set Ripiano = @RipianoPiuLibero
        where Esemplare = EsemplareSingolo;
        
        #Inseriamo infine l'esemplare in isolamento
        insert into Isolamento values
			(EsemplareSingolo, @SezioneInCuiSpostare);
    end loop;
end $$

delimiter ;

#Event che ogni mese popola il report riguardante la necessità di personale per gestire gli interventi.
#Per gestire il numero di assunzioni, il database sfrutta la seguente formula:
# - In un mese, non è necessario assumere nouvi addetti se vale:
#				E < 0.8 * (N*20*22)
#	dove E è l'entità totale degli interventi da effettuare in quel mese, N il numero di addetti che si occupano degli interventi,
#	20 rappresenta l'entità totale gestibile da un singolo addetto in un giorno e 22 è il numero di giorni lavorativi medio in un mese

drop event if exists EventPopolamentoReportAssunzioni;

DROP TABLE IF EXISTS `progettouni`.`MV_ReportAssunzioni` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`MV_ReportAssunzioni` (
  `idReport` INT(11) NOT NULL AUTO_INCREMENT,
  `Data` DATE NOT NULL,
  `NumAssunzioni` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Mese` INT(11) NOT NULL,
  PRIMARY KEY (`idReport`)
  )
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

drop procedure if exists EventPopolamentoReportAssunzioni;

delimiter $$

create procedure EventPopolamentoReportAssunzioni ()
#on schedule every 1 month
#starts '2016-07-01 00:30:00'
#do
begin
	set @NumDipendenti = 0.8 * (								#Si considera che l'80% dei dipendenti si occupa di interventi a domicilio
									select sum(NumDipendenti)
                                    from Sede
                                    );
	set @Contatore = 0;
    set @MeseAttuale = month(current_date());
    set @AnnoAttuale = year(current_date());
    AssunzioniMese: loop
		if(@Contatore = 6) then
			leave AssunzioniMese;
        end if;
        
        #Individuiamo il mese per cui fare il report
        set @Mese = @MeseAttuale + @Contatore;
        if (@Mese > 12) then
			set @Mese = @Mese - 12;
            set @AnnoAttuale = year(current_date()) + 1;
        end if;
        
        
        #Calcoliamo il numero di interventi nel mese rappresentato dal contatore
        set @EntitaTot = (
								select sum(Entita)
                                from Intervento
                                where Effettuato = false and
									month(Data) = @Mese and
                                    year(Data) = @AnnoAttuale
								);
                                
		
        #Controlliamo che sia rispettata la condizione spiegata sopra e, in caso, creiamo un'occorrenza di report
        set @NumAssunzioni = 0;
        if(@EntitaTot >= 0.8 * @NumDipendenti * 20 * 22) then
			set @NumAssunzioni = (@EntitaTot - 0.8 * @NumDipendenti * 20 * 22)/(0.8*20*22); #Il numeratore rappresenta l'entità da gestire in quel mese
																							#Il denominatore rappresenta l'entità che un impiegato può
																							#gestire in un mese
		
        
        end if;
        
        insert into MV_ReportAssunzioni (`Data`, `NumAssunzioni`, `Mese`) values
				(current_date(), @NumAssunzioni, @Mese);
        
        set @Contatore = @Contatore + 1;
    end loop;
end $$

delimiter ;

#Questo event, che si ripete ogni mese, analizza le vendite nei mesi scorsi per stabilire la quantità di esemplari da acquistare
#per una data specie di pianta. Nello specifico, l'event, per ogni pianta, ragiona così:
# - inizializza il numero di esemplari con il numero di esemplari venduti lo scorso mese; a questo valore somma le pendenze e sottrae
#   gli esemplari già in azienda
# - se gli esemplari attualmente in azienda non sono più del 20% rispetto agli esemplari venduti, si aggiunge un 5% al valore iniziale
#   per sicurezza
# - vado a controllare la crescita nelle vendite rispetto al mese precedente: se negativa o inferiore al 5%, il valore finora ottenuto
#   rimane inalterato; se compresa fra 5-10%, ma confermata da una crescita positiva anche nel mese ancora precedente, aggiungo al valore
#   la stessa percentuale di crescita avuta nel mese scorso; se maggiore del 10%, aggiungo questa percentuale di crescita, a meno di non
#   aver avuto un calo superiore a questa crescita nel mese precedente (nel qual caso l'aumento si ferma al 10%)
# - infine, se il mese attuale coincide o con l'inizio del periodo di fioritura o con quello di fruttificazione, aggiungo un ulteriore 10%
#Da notare che, se c’è stata una (de)crescita superiore al 10%, questa viene comunque segnalata all'azienda

drop event if exists EventPopolamentoReportConsigliAcquisto;

delimiter $$

#Essendo un'operazione piuttosto pesante, le 2 di notte è un orario più che adeguato per effettuarla
create event EventPopolamentoReportConsigliAcquisto
on schedule every 1 month
starts '2016-07-01 02:00:00'
do
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare NumPendenza int default 0;
    declare CrescitaSostenuta bool default false;
    declare DecrescitaSostenuta bool default false;
    declare PianteReport cursor for
		select idPianta
        from Pianta;
	declare continue handler for
		not found set finito = 1;

	open PianteReport;
    
    prelievo: loop
		fetch PianteReport into PiantaSingola;
        if(finito = 1) then
			leave prelievo;
        end if;
        
        #Per chiarezza: con Mese scorso si intede il mese appena finito; con mese precedente, quello che lo ha preceduto;
        #con mese precedente precedente quello che è venuto ancora prima;
        
        #---------------------------------------------------------------------------------------------
        #    DATI SUL MESE APPENA FINITO
        #---------------------------------------------------------------------------------------------
        
		#Calcoliamo gli ordini in pendenza per questa pianta
        set NumPendenza = (
								select sum(Quantita)
                                from Pendente
                                where Pianta = PiantaSingola
                                );
		#Calcoliamo quanti esemplari ne sono stati venduti
		set @NomePianta = (
								select Nome
                                from Pianta
                                where idPianta = PiantaSingola
                                );
		set @NumVendite = (
								select count(*)
                                from Scheda
                                where NomePianta = @NomePianta and
									DataAcquisto > current_date() - interval 1 month
								);
		#Calcoliamo gli esemplari in azienda (da fare solo se attualmente non ci sono pendenze)
        if(NumPendenza = 0) then
			set @NumAzienda = (
								select count(*)
                                from Esemplare
                                where venduto = false and
									Pianta = PiantaSingola
                                    );
		else set @NumAzienda = 0;
        end if;
        
        #Determiniamo se è il caso di aggiungere un 5% di sicurezza analizzando il rapporto fra gli esemplari in azienda e quelli venduti
        if(@NumAzienda < 0.2 * @NumVendite) then
			set @AcquistiTotaliDaFare = (@NumVendite + NumPendenza)*1.05;
		else set @AcquistiTotaliDaFare = @NumVendite + NumPendenza;
        end if;
        
        #------------------------------------------------------------------------------------------------
        #     ANALISI DATI MESE PRECEDENTE E MESE PRECEDENTE PRECEDENTE
        #------------------------------------------------------------------------------------------------
        
        #Si noterà che qui non viene considerata la pendenza: questo è stato deciso perché gli ordini in pendenza sono
        #una netta minoranza sul totale e andarli a considerare appesantirebbe inutilmente la query
        
        #Recuperiamo le vendite del mese precedente e del mese precedente precedente
        set @VenditeMesePrecente = (
										select count(*)
                                        from Scheda
                                        where DataAcquisto between (current_date() - interval 2 month)
											and (current_date() - interval 1 month) and
                                            NomePianta = @NomePianta
                                            );
		set @VediteMesePrecedentePrecedente = (
												select count(*)
												from Scheda
												where DataAcquisto between (current_date() - interval 3 month)
													and (current_date() - interval 2 month) and
													NomePianta = @NomePianta
                                                );
        #Controlliamo la crescita del mese scorso rispetto al mese precedente e la crescita del mese precedente
        #rispetto a quello precedente precedente
        set @PercentualeCrescitaMeseScorso = (@NumVendite - @VenditeMesePrecedente)/@VenditeMesePrecedente;
        set @PercentualeCrescitaMesePrecedente = (@VenditeMesePrecedente - @VenditeMesePrecedentePrecedente)/@VenditeMesePrecedentePrecedente;
        
        #---------------------------------------------------------------------------------------------------
        #     ANALISI DELLA CRESCITA
        #---------------------------------------------------------------------------------------------------
        
        #Controlliamo i vari casi
        
        #Se c'è stata una decrescita superiore al 10%, non modifichiamo il numero, ma andiamo ad inserire una nota nel report
        if(@PercentualeCrescitaMeseScorso < -0.1) then
			set DecrescitaSostenuta = true;
            
		#Se la crescita nel mese scorso è stata fra 5-10% ed è confermata da un trend positivo anche nel mese precedente,
		#si aggiunge la percentuale di crescita al calcolo che avevamo fatto prima, altrimenti si lascia tutto com'è;
        elseif(@PercentualeCrescitaMeseScorso > 0.05 and @PercentualeCrescitaMeseScorso < 0.1) then
			if(@PercentualeCrescitaMesePrecedente > 0)then
				set @AcquistiTotaliDaFare = @AcquistiTotaliDaFare * (1 + @PercentualeCrescitaMeseScorso);
            end if;
		
        #Se la crescita nel mese scorso è stata superiore al 10% e non c'è stata nel mese precedente una decrescita superiore
		#al 10%, si aggiunge la percentuale di crescita al calcolo di prima, altrimenti si aggiunge un 10%; in entrambi i casi,
        #andiamo poi ad inserire una nota nel report
        elseif(@PercentualeCrescitaMeseScorso > 0.1)then
			set CrescitaSostenuta = true;
			if(@PercentualeCrescitaMesePrecedente > -0.1) then
				set @AcquistiTotaliDaFare = @AcquistiTotaliDaFare * (1 + @PercentualeCrescitaMeseScorso);
			else set @AcquistiTotaliDaFare = @AcquistiTotaliDaFare * 1.1;
            end if;			
        end if;
        
        #-----------------------------------------------------------------------------------------------------------
        #   ANALISI PERIODO FIORITURA
        #-----------------------------------------------------------------------------------------------------------
        
        #Verifichiamo se il mese attuale corrisponde all'inizio di un periodo di fioritura e/o fruttificazione
        if (month(current_date()) in (
										select PC.InizioPeriodo
										from PeriodoCicli PC inner join CicliPianta CP
											on PC.idPeriodo = CP.Periodo
										where CP.Pianta = PiantaSingola and
											(Fio_Fru = 'Fioritura' or 
                                             Fio_Fru = 'Fruttificazione' or
                                             Fio_Fru = 'Entrambe')
										)) then
			set @AcquistiTotaliDaFare = @AcquistiTotaliDaFare * 1.1;
        end if;
        
        #-----------------------------------------------------------------------------------------------------------
        #   POPOLAMENTO FINALE
        #-----------------------------------------------------------------------------------------------------------
        
        #Controlliamo che non ci siano note aggiuntive da inserire nel report
        set @NoteAggiuntive = '';
        if(CrescitaSostenuta = true) then
			set @NoteAggiuntive = '    ATTENZIONE: Crescita superiore al 10%';
		elseif (CrescitaSostenuta = true) then
			set @NoteAggiuntive = '    ATTENZIONE: Decrescita superiore al 10%';
		end if;
        
		#Inseriamo infine i dati nella tabella ReportConsigliAcquisto; in Note viene specificato per quali piante c'è
        #pendenza (e in che misura), così da permettere all'azienda di stabilire una priorità in base a questo dato
		insert into ReportConsigliAcquisto(`Pianta`, `Data`, `Quantita`, `Note`) values
			(PiantaSingola, current_date(), @AcquistiTotaliDaFare, concat('Esemplari in pendenza: ', concat(NumPendenza, @NoteAggiuntive)));
    end loop;
end $$

delimiter ;

#Questo event, che scatta una volta all'anno, controlla se è necessario fare eventuali segnalazioni riguardanti le possibili predisposizioni di una
#pianta ad ammalarsi. Queste segnalazioni vengono aggiunte al campo "Note" di "ReportConsigliAcquisto"
#Un esemplare viene segnalato quando il rapporto fra esemplari che si sono ammalati ed esemplari totali supera la media del 10%.
#Il calcolo viene effettuato basandosi sulle sole malattie segnalate in azienda (quelle all'esterno potrebbero non essere altrettanto affidabili)

drop event if exists EventSegnalazioniPianteDeboli;

delimiter $$

create event EventSegnalazioniPianteDeboli
on schedule every 1 year
starts '2016-12-15 00:00:01'
do
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare NumMalattie int;
    declare NumTotale int;
    #Calcoliamo il numero di malattie nell'ultimo anno per ogni pianta
	declare PianteDeboli cursor for
		select Pianta,
			count(*) as Malattie
		from Esemplare E inner join Scheda S
			on E.idEsemplare = S.Esemplare
            inner join ReportDiagnostica RD
            on E.idEsemplare  = RD.Esemplare
        where (DataAcquisto > current_date() - interval 1 year or
			DataAcquisto is null) and
			RD.Data > current_date() - interval 1 year
        group by Pianta;
	declare continue handler for
		not found set finito = 1;
        
	open PianteDeboli;
    
    #Temporary table di supporto
    create temporary table if not exists RapportiMalattiaTotale(
		Pianta int not null,
        Rapporto double,
        primary key (Pianta)
    ) Engine = InnoDB default charset = latin1;
    
    prelievo: loop
		fetch PianteDeboli into PiantaSingola, NumMalattie;
        if(finito = 1) then
			leave prelievo;
        end if;
        
        #Prendiamo gli esemplari di questa pianta transitati in azienda nell'ultimo anno
        set NumTotale = (
							select count(*)
                            from Esemplare E inner join Scheda S
								on E.idEsemplare = S.Esemplare
							where (DataAcquisto > current_date() - interval 1 year or
								DataAcquisto is null) and
								E.Pianta = PiantaSingola
                                );
		
        set @Rapporto = NumMalattie/NumTotale;
        
        #Inseriamo nella temporary table di supporto
        insert into RapportiMalattiaTotale values
			(PiantaSingola, @Rapporto);
            
    end loop;
    
    
    #Andiamo ora ad aggiornare il campo "Note" in "ReportConsigliDiAcquisto"
    set @Segnalazione = '    -   ATTENZIONE: La pianta ha una particolare predisposizione ad ammalarsi';
    
    update ReportConsigliAcquisto RCA inner join RapportiMalattieTotali RMT
		on RCA.Pianta = RMT.Pianta
    set Note = concat(Note, @Segnalazione)
    where month(Data) = month(current_date()) and
		RMT.Rapporto > 1.2 * (
								select avg(Rapporto)
                                from RapportiMalattieTotali
                                );
    
    close PianteDeboli;
    
    truncate RapportiMalattiaTotale;
end $$

delimiter ;