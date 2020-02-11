

#I trigger di seguito sono creati per organizzare una mailing list; in questa mailing list vengono inseriti gli utenti a cui va notificato
#un intervento, quelli a cui vogliamo notificare un cambiamento di prezzo nelle proprie piante preferite, quelli a cui vogliamo suggerire
#di inserire le proprie preferenze qualora non l'abbiano già fatto e infine quelli a cui vogliamo inviare una mail di benvenuto

#Prima di tutto creiamo una temporary table in cui andiamo ad inserire gli utenti interessati
drop table if exists MV_MailingList;
create table MV_MailingList( 
	IndirizzoMail varchar(100) not null,
    Mail varchar(700) not null,
    primary key (IndirizzoMail, Mail)
)Engine = InnoDB default charset = latin1;

drop trigger if exists TriggerAggiornaMailingListCambioPrezzo;
drop event if exists EventAggiornaMailingListSuggerimento;
drop trigger if exists TriggerAggiornaMailingListBenvenuto;
drop event if exists EventAggiornaMailingListNotificaIntervento;
drop event if exists EventInvioMail;

delimiter $$

#Il primo trigger notifica semplicemente un cambio di prezzo per qualche pianta agli utenti che l'hanno inserita fra le proprie preferite
create trigger TriggerAggiornaMailingListCambioPrezzo
after update on Pianta
for each row
begin
	#Se abbiamo aggiornato il costo della pianta mettendocene uno minore, lo notifichiamo agli utenti interessati
	if(new.CostoBase < old.CostoBase) then
		#Qui così come negli altri trigger, le mail vengono costruite pezzo per pezzo, inserendo di volta in volta il valore corrispondente
		set @Mail = 'Ciao ';
        #Qui si inserisce il nome dell'utente, se specificato, altrimenti inseriamo il nickname
        set @MailSecondaParte =', sappiamo che sei interessato alla pianta ';
        #Qui si inserisce il nome della pianta
        set @MailSecondaParte =concat(@MailSecondaParte, new.Nome);
        set @MailSecondaParte =concat(@MailSecondaParte, '. Lo sai che si è appena abbassata di prezzo? Corri subito da noi a comprarla!');
        #Qui si inseriscono tutti i record interessati nella Mailing list
		insert into MV_MailingList (`IndirizzoMail`, `Mail`)
			select A.Email, if(Nome is not null, concat(@Mail, concat(Nome, @MailSecondaParte)), concat(@Mail, concat(Nickname, @MailSecondaParte)))
            from Account A inner join PiantePreferite P
					on A.idAccount = P.Account
			where P.Pianta = new.idPianta;
    end if;
end $$


#Questo event si occupa di suggerire agli utenti di inserire nel database le proprie piante preferite, così da ricevere offerte e notizie
create event EventAggiornaMailingListSuggerimento
on schedule every 1 month
starts '2016-06-15 00:00:01'
do
begin
	set @Mail = 'Ciao ';
	set @MailSecondaParte =', a quanto pare non ci hai ancora detto quali sono le tue piante preferite. Vieni subito a dircelo, così sappiamo se informarti quando una pianta scende di prezzo!';
	insert into MV_MailingList (`IndirizzoMail`, `Mail`)
		select A.Email, if(Nome is not null, concat(@Mail, concat(Nome, @MailSecondaParte)), concat(@Mail, concat(Nickname, @MailSecondaParte)))
		from Account A
        where not exists (
							select *
                            from PiantePreferite P
                            where A.idAccount = P.Account
                            );
end $$


#Qui si crea semplicemente una mail di benvenuto
create trigger TriggerAggiornaMailingListBenvenuto
after insert on Account
for each row
begin
	set @Mail = 'Ciao ';
	set @MailSecondaParte =', benvenuto nella nostra comunità! Nel nostro store troverai le migliori offerte di piante sul web, mentre nel nostro forum troverai consigli, notizie e molto altro dal mondo del giardinaggio! Vieni subito a scoprire tutti gli altri servizi offerti dalla nostra azienda, ti aspettiamo con ansia!';
	insert into MV_MailingList (`IndirizzoMail`, `Mail`)
		values (new.Email, if(new.Nome is not null, concat(@Mail, concat(new.Nome, @MailSecondaParte)), concat(@Mail, concat(new.Nickname, @MailSecondaParte))));
end $$


#Qui si crea una mail per avvertire gli utenti che è necessario effettuare un intervento su una data pianta
create event EventAggiornaMailingListNotificaIntervento
on schedule every 1 day
starts '2016-06-12 00:00:01'
do
begin
	declare finito int default 0;
    declare InterventoSingolo int;
    declare EsemplareSingolo int;
    declare InterventiDaNotificare cursor for
		select idIntervento,
			Esemplare
		from Intervento
        where Data = current_date() + interval 2 day;
	
    declare continue handler for
		not found set finito = 1;
	
    #Notifichiamo gli interventi tramite email
	set @Mail = 'Ciao ';
	set @MailSecondaParte =', ci risulta che il tuo esemplare di ';
    set @MailTerzaParte = ' debba a breve effettuare un intervento di ';
    set @MailQuartaParte = '. Se hai scelto di usufruire del nostro servizio di manutenzione a domicilio, presto dei nostri addetti verranno ad occuparsene. Buon giardinaggio!';
	insert into MV_MailingList (`IndirizzoMail`, `Mail`)
		select A.Email, 
			if(A.Nome is not null, 
				concat(@Mail, 
                concat(A.Nome, 
                concat(@MailSecondaParte, 
                concat(S.NomePianta, 
                concat(@MailTerzaParte, 
                concat(I.Tipo, @MailQuartaParte)))))),
                concat(@Mail, 
                concat(A.Nickname, 
                concat(@MailSecondaParte, 
                concat(S.NomePianta, 
                concat(@MailTerzaParte, 
                concat(I.Tipo, @MailQuartaParte)))))))
		from Intervento I inner join Scheda S
			on I.Esemplare = S.Esemplare
            inner join Account A
            on S.Account = A.idAccount
        where I.Data = current_date() + interval 2 day and
			I.Effettuato = false and
            (I.Motivo = 'Programmato' or
            I.Motivo = 'Automatico');
            
	#Dopo aver avvertito gli utenti, ci occupiamo di aggiornare le stime sull'entità dell'intervento; per farlo, sommiamo tutti gli interventi di uno stesso tipo
    #che l'utente avrebbe dovuto effettuare più di un mese fa
    open InterventiDaNotificare;
    
    prelievo: loop
		fetch InterventiDaNotificare into InterventoSingolo, EsemplareSingolo;
        if (finito = 1) then
			leave prelievo;
        end if;
        
        #Calcoliamo la somma delle entità degli interventi vecchi non effettuati
        set @SommaEntita = (
								select sum(Entita)
                                from Intervento
                                where Esemplare = EsemplareSingolo and
									effettuato = false and
                                    Data < current_date() - interval 1 month
                                    );
		
        #Aggiorniamo l'entità di questo intervento
        update Intervento
        set Entita = Entita + @SommaEntita
        where idIntervento = InterventoSingolo;
    end loop;    
    
    close InterventiDaNotificare;
end $$


#Infine si "inviano le mail"
create event EventInvioMail
on schedule every 1 day
starts '2016-06-12 00:00:01'
do
begin
	#Questo truncate nel nostro database equivale ad aver inviato le mail
	truncate MV_MailingList;
end $$


delimiter ;



#Trigger che aggiornano la credibilità di un utente
drop trigger if exists AggiornaCredibilitaUtenteCreazionePost;

drop trigger if exists AggiornaCredibilitaUtenteCreazioneRisposta;

drop trigger if exists AggiornaCredibilitaUtenteCreazioneVoto;

drop trigger if exists inserimentoPost;
drop trigger if exists inserimentoRisposta;
drop trigger if exists inserimentoVoto;

delimiter $$


create trigger inserimentoPost
before insert on Post
for each row
begin
	set new.Timestamp = current_timestamp();
end$$

create trigger inserimentoRisposta
before insert on Risposta
for each row
begin
	set new.Timestamp = current_timestamp();
end$$



#Il primo trigger aggiorna la credibilità dopo la creazione di un nuovo post
create trigger AggiornaCredibilitaUtenteCreazionePost
after insert on Post
for each row
begin

	#Si è deciso in fase di creazione del database di assegnare 2 punti per ogni post aperto
	update Account
    set Credibilita = Credibilita + 2
    where idAccount = new.Account;
end $$

delimiter ;

delimiter $$

#Il secondo trigger aggiorna la credibilità dopo la creazione di una nuova risposta
create trigger AggiornaCredibilitaUtenteCreazioneRisposta
after insert on Risposta
for each row
begin
	#Si è deciso in fase di creazione del database di assegnare 5 punti per ogni post aperto
	update Account
    set Credibilita = Credibilita + 5
    where idAccount = new.Account;
end $$

delimiter ;

delimiter $$

create trigger inserimentoVoto
before insert on Voto
for each row
begin
	#Controlliamo che l'utente non si stia votando da solo
    if(new.AccountRisposta = new.AccountVotante) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Non puoi votarti da solo!';
    end if;
    #In più dobbiamo controllare che l'utente non abbia già espresso un giudizio per questa risposta
    if(exists(
				select *
                from Voto
                where AccountVotante = new.AccountVotante and
					TimeStampRisposta = new.TimeStampRisposta and
                    AccountRisposta = new.AccountRisposta
				))then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Hai già votato per questa risposta!';
	end if;
end $$

#Il terzo trigger aggiorna la credibilità di un utente dopo che questi ha ricevuto un voto
create trigger AggiornaCredibilitaUtenteCreazioneVoto
after insert on Voto
for each row
begin
	#Si è deciso in fase di creazione del database di assegnare i punti secondo questo criterio:
    #i*n dove i è assegnato in base al giudizio e n è assegnato in base alla credibilità dell'utente votante
    declare PunteggioVotante int;
    declare PunteggioGuadagnato int;
    #Per calcolare n usiamo questa formula:
    #n = 1 + [Punteggio del votante / 10000]
    set PunteggioVotante = (
								select Credibilita
                                from Account
                                where idAccount = new.AccountVotante
							)/10000;
	set PunteggioVotante = 1 + PunteggioVotante;
    #Per calcolare i usiamo questo criterio
	if (new.Giudizio = 1) then
		set PunteggioGuadagnato = -2;
	elseif(new.Giudizio = 2) then
		set PunteggioGuadagnato = -1;
	elseif(new.Giudizio = 3) then
		set PunteggioGuadagnato = 1;
	elseif(new.Giudizio = 4) then
		set PunteggioGuadagnato = 3;
	elseif(new.Giudizio = 5) then
		set PunteggioGuadagnato = 5;
	end if;
    #Procediamo quindi al calcolo del punteggio guadagnato e aggiorniamo la credibilità dell'utente che ha fatto la risposta
    set PunteggioGuadagnato = PunteggioGuadagnato * PunteggioVotante;
    
	update Account
    set Credibilita = Credibilita + PunteggioGuadagnato
    where idAccount = new.AccountRisposta;
end $$

delimiter ;

#Trigger che, all'inserimento di un'occorrenza di "EsigenzeElemento", si assicura di mantenere coerente l'informazione con "EsigenzeTerreno"

drop trigger if exists TriggerAggiornaEsigenzeTerreno;

delimiter $$

create trigger TriggerAggiornaEsigenzeTerreno
after insert on EsigenzeElemento
for each row
begin
	set @Consistenza = (
						select Consistenza
                        from Terreno T inner join Esigenze E
							on T.idTerreno = E.Terreno
                        where E.Pianta = new.Pianta
                        );
	set @Permeabilita = (
						select Permeabilita
                        from Terreno T inner join Esigenze E
							on T.idTerreno = E.Terreno
                        where E.Pianta = new.Pianta
                        );
	set @pH = (
						select pH
                        from Terreno T inner join Esigenze E
							on T.idTerreno = E.Terreno
                        where E.Pianta = new.Pianta
                        );
	if(not exists(
					select *
                    from Terreno T inner join ComposizioneTerreno CT
						on T.idTerreno = CT.Terreno
                        inner join EsigenzeElemento EE
                        on (CT.Elemento = EE.Elemento and
							CT.Concentrazione = EE.Concentrazione)
					where EE.Pianta = new.Pianta and
						T.Consistenza = @Consistenza and
                        T.Permeabilita = @Permeabilita and
                        T.pH = @pH
					group by T.idTerreno
                    having count(distinct CT.Elemento) = (
														select count(*)
                                                        from EsigenzeElemento
                                                        where Pianta = new.Pianta
                                                        ))
		) then
        
        #Inseriamo una nuova occorrenza di terreno
        insert into Terreno (`Consistenza`, `Permeabilita`, `pH`) values
			(@Consistenza, @Permeabilita, @pH);
            
		#Individuiamo l'id
		set @NuovoTerreno = (
								select idTerreno
                                from Terreno T
                                where idTerreno >= all(						#Essendo idTerreno un auto_increment, possiamo usare questo metodo
														select T1.idTerreno
                                                        from Terreno T1
                                                        where not exists (
																			select *
                                                                            from ComposizioneTerreno CT1
                                                                            where T1.idTerreno = CT1.Terreno
                                                                            )
                                                        )
										and not exists (
															select *
															from ComposizioneTerreno CT1
															where T.idTerreno = CT1.Terreno
															)
								);
		
        #Inseriamo gli elementi in "ComposizioneTerreno"
        insert into ComposizioneTerreno (`Terreno`, `Elemento`, `Concentrazione`)
			select @NuovoTerreno,
				Elemento,
                Concentrazione
			from EsigenzeElemento
            where Pianta = new.Pianta;
        
        #Aggiorniamo "Esigenze"
        update Esigenze
        set Terreno = @NuovoTerreno
        where Pianta = new.Pianta;
    else 
		set @NuovoTerreno = (
								select idTerreno
								from Terreno T inner join ComposizioneTerreno CT
									on T.idTerreno = CT.Terreno
									inner join EsigenzeElemento EE
									on (CT.Elemento = EE.Elemento and
										CT.Concentrazione = EE.Concentrazione)
								where EE.Pianta = new.Pianta and
									T.Consistenza = @Consistenza and
									T.Permeabilita = @Permeabilita and
									T.pH = @pH
								group by T.idTerreno
								having count(distinct CT.Elemento) = (
																	select count(*)
																	from EsigenzeElemento
																	where Pianta = new.Pianta
																	)
								limit 1 #Il limit 1 è una sicurezza in più, in realtà non dovrebbero esserci doppioni
							);
		
        #Aggiorniamo le esigenze
        update Esigenze
        set Terreno = @NuovoTerreno
        where Pianta = new.Pianta;
	end if;
end $$

delimiter ;



#Trigger che, all'inserimento di una pianta in un settore, calcola la luce attuale del settore stesso secondo la seguente formula:
# - Si prende la luce iniziale del settore (passata dall'utente)
# - Se, con la somma delle aree delle piante (approssimate a cerchi), si supera il 50%, la luce passa automaticamente
#	a indiretta e la sua quantità diventa 'Mezz'ombra'
# - Se, la somma supera l'80%, diventa 'Ombra'
#In più, questo trigger chiama la funzione che aggiorna le piante consigliate

drop trigger if exists TriggerAggiornaLuceSettoreInsert;

drop trigger if exists TriggerAggiornaLuceSettoreUpdate;

drop trigger if exists TriggerAggiornaLuceSettoreDelete;

delimiter $$

create trigger TriggerAggiornaLuceSettoreInsert
after insert on FormaPianta
for each row
begin
	#Prendiamo luce iniziale, area ed area occupate del settore
	set @LuceIniziale = (
							select LuceIniziale
                            from Settore
                            where idSettore = new.Settore
                            );
	if(@LuceIniziale is not null) then	#Tutto il resto del trigger ha senso solo se l'utente ha specificato la luce iniziale
		set @NumOre = (
						select NumOre
						from Luce 
						where idLuce = @LuceIniziale
						);
		set @Area = (
						select Area
						from Settore
						where idSettore = new.Settore
						);
		set @AreaOccupata = (
								select sum(3.14 * Dim * Dim /4)
								from FormaPianta
								where Settore = new.Settore
								);
		#Verifichiamo se una delle condizioni è verificata e, nel caso, calcoliamo la nuova luminosità
		if(@AreaOccupata > 0.5 * @Area) then
			if(@AreaOccupata > 0.8 * @Area) then
				if(not exists(													#Prima di assegnare un valore a @LuceAttuale, dobbiamo assicurarci che 
							select *											#esista effettivamente un'occorrenza di luce come la vogliamo noi
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Bassa' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Bassa', false);
				end if;
				set @LuceAttuale = (
											select idLuce
											from Luce
											where NumOre = @NumOre and
												Quantita = 'Bassa' and
												Diretta = false
										);
			else 
				if(not exists(
							select *
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Media' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Media', false);
				end if;
				set @LuceAttuale = (
										select idLuce
										from Luce
										where NumOre = @NumOre and
											Quantita = 'Media' and
											Diretta = false
									);
			end if;
		end if;
    
		#Aggiorniamo quindi il settore
		update Settore
		set LuceAttuale = @LuceAttuale
		where idSettore = new.Settore;
    
    end if;
end $$

delimiter ;

delimiter $$

create trigger TriggerAggiornaLuceSettoreUpdate
after update on FormaPianta
for each row
begin
	#Prendiamo luce iniziale, area ed area occupate del settore
	set @LuceIniziale = (
							select LuceIniziale
                            from Settore
                            where idSettore = new.Settore
                            );
	if(@LuceIniziale is not null) then	#Tutto il resto del trigger ha senso solo se l'utente ha specificato la luce iniziale
		set @NumOre = (
						select NumOre
						from Luce 
						where idLuce = @LuceIniziale
						);
		set @Area = (
						select Area
						from Settore
						where idSettore = new.Settore
						);
		set @AreaOccupata = (
								select sum(3.14 * Dim * Dim / 4)
								from FormaPianta
								where Settore = new.Settore
								);
		#Verifichiamo se una delle condizioni è verificata e, nel caso, calcoliamo la nuova luminosità
		if(@AreaOccupata > 0.5 * @Area) then
			if(@AreaOccupata > 0.8 * @Area) then
				if(not exists(													#Prima di assegnare un valore a @LuceAttuale, dobbiamo assicurarci che 
							select *											#esista effettivamente un'occorrenza di luce come la vogliamo noi
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Bassa' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Bassa', false);
				end if;
				set @LuceAttuale = (
											select idLuce
											from Luce
											where NumOre = @NumOre and
												Quantita = 'Bassa' and
												Diretta = false
										);
			else 
				if(not exists(
							select *
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Media' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Media', false);
				end if;
				set @LuceAttuale = (
										select idLuce
										from Luce
										where NumOre = @NumOre and
											Quantita = 'Media' and
											Diretta = false
									);
			end if;
		end if;
    
		#Aggiorniamo quindi il settore
		update Settore
		set LuceAttuale = @LuceAttuale
		where idSettore = new.Settore;
    
    end if;
end $$

delimiter ;

delimiter $$

create trigger TriggerAggiornaLuceSettoreDelete
after delete on FormaPianta
for each row
begin
	#Prendiamo luce iniziale, area ed area occupate del settore
	set @LuceIniziale = (
							select LuceIniziale
                            from Settore
                            where idSettore = old.Settore
                            );
	if(@LuceIniziale is not null) then	#Tutto il resto del trigger ha senso solo se l'utente ha specificato la luce iniziale
		set @NumOre = (
						select NumOre
						from Luce 
						where idLuce = @LuceIniziale
						);
		set @Area = (
						select Area
						from Settore
						where idSettore = old.Settore
						);
		set @AreaOccupata = (
								select sum(3.14 * Dim * Dim / 4)
								from FormaPianta
								where Settore = old.Settore
								);
		#Verifichiamo se una delle condizioni è verificata e, nel caso, calcoliamo la nuova luminosità
		if(@AreaOccupata > 0.5 * @Area) then
			if(@AreaOccupata > 0.8 * @Area) then
				if(not exists(													#Prima di assegnare un valore a @LuceAttuale, dobbiamo assicurarci che 
							select *											#esista effettivamente un'occorrenza di luce come la vogliamo noi
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Bassa' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Bassa', false);
				end if;
				set @LuceAttuale = (
											select idLuce
											from Luce
											where NumOre = @NumOre and
												Quantita = 'Bassa' and
												Diretta = false
										);
			else 
				if(not exists(
							select *
							from Luce
							where NumOre = @NumOre and
								Quantita = 'Media' and
								Diretta = false
								))then
					insert into Luce (`NumOre`, `Quantita`, `Diretta`) values
						(@NumOre, 'Media', false);
				end if;
				set @LuceAttuale = (
										select idLuce
										from Luce
										where NumOre = @NumOre and
											Quantita = 'Media' and
											Diretta = false
									);
			end if;
		end if;
    
		#Aggiorniamo quindi il settore
		update Settore
		set LuceAttuale = @LuceAttuale
		where idSettore = old.Settore;
    
    end if;
end $$

delimiter ;
#Trigger che, all'inserimento/aggiornamento/cancellazione di una sezione, aggiorna il numero massimo di piante nella serra corrispondente
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSerraInsert;
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSerraUpdate;
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSerraDelete;

delimiter $$

create trigger TriggerAggiornaNumeroMassimoPianteSerraInsert
after insert on Sezione
for each row
begin
	update Serra S
    set S.MaxPiante = S.MaxPiante + new.MaxPiante
    where S.idSerra = new.Serra;
end $$

create trigger TriggerAggiornaNumeroMassimoPianteSerraUpdate
after update on Sezione
for each row
begin
	if(new.MaxPiante <> old.MaxPiante) then
		update Serra S
		set S.MaxPiante = S.MaxPiante + new.MaxPiante - old.MaxPiante
		where S.idSerra = new.Serra;
    end if;
end $$

create trigger TriggerAggiornaNumeroMassimoPianteSerraDelete
after delete on Sezione
for each row
begin
	update Serra S
    set S.MaxPiante = S.MaxPiante - old.MaxPiante
    where S.idSerra = old.Serra;
end $$

delimiter ;
#Trigger che, all'inserimento/aggiornamento/cancellazione di un ripiano, aggiorna il numero massimo di piante nella sezione corrispondente
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSezioneInsert;
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSezioneUpdate;
drop trigger if exists TriggerAggiornaNumeroMassimoPianteSezioneDelete;

delimiter $$

create trigger TriggerAggiornaNumeroMassimoPianteSezioneInsert
after insert on Ripiano
for each row
begin
	update Sezione S
    set S.MaxPiante = S.MaxPiante + new.MaxPiante
    where S.idSezione = new.Sezione;
end $$

create trigger TriggerAggiornaNumeroMassimoPianteSezioneUpdate
after update on Ripiano
for each row
begin
	if(new.MaxPiante <> old.MaxPiante) then
		update Sezione S
		set S.MaxPiante = S.MaxPiante + new.MaxPiante - old.MaxPiante
		where S.idSezione = new.Sezione;
    end if;
end $$

create trigger TriggerAggiornaNumeroMassimoPianteSezioneDelete
after delete on Ripiano
for each row
begin
	update Sezione S
    set S.MaxPiante = S.MaxPiante - old.MaxPiante
    where S.idSezione = old.Sezione;
end $$

delimiter ;
#Trigger che, all'inserimento di un nuovo contenitore, aggiorna il numero di piante nella serra e sezione relativa
drop trigger if exists AggiornaNumeroPianteInsert;

delimiter $$

create trigger AggiornaNumeroPianteInsert
after insert on Contenitore
for each row
begin
	#Individuiamo la Sezione interessata
	set @Sezione = (
				select Sezione
                from Ripiano
                where idRipiano = new.Ripiano
                );
	#Aggiorniamo il numero di piante
	update Sezione
    set NumPiante = NumPiante +1
    where idSezione = @Sezione;
    
	#Individuiamo la Serra interessata
	set @Serra = (
				select Serra
                from Sezione
                where idSezione = @Sezione
                );
	#Aggiorniamo il numero di piante
	update Serra
    set NumPiante = NumPiante +1
    where idSerra = @Serra;
end$$

delimiter ;

#Trigger che, allo spostamento di un contenitore, aggiorna il numero di piante nelle serre e sezioni relative
drop trigger if exists AggiornaNumeroPianteSezioniUpdate;

delimiter $$

create trigger AggiornaNumeroPianteSezioniUpdate
after update on Contenitore
for each row
begin
	#Individuiamo la Sezione interessata
	set @Sezione = (
				select Sezione
                from Ripiano
                where idRipiano = new.Ripiano
                );
	#Aggiorniamo il numero di piante
	update Sezione
    set NumPiante = NumPiante +1
    where idSezione = @Sezione;
    
	#Individuiamo la Serra interessata
	set @Serra = (
				select Serra
                from Sezione
                where idSezione = @Sezione
                );
	#Aggiorniamo il numero di piante
	update Serra
    set NumPiante = NumPiante +1
    where idSerra = @Serra;
    
    #Individuiamo la Sezione interessata
	set @Sezione = (
				select Sezione
                from Ripiano
                where idRipiano = old.Ripiano
                );
	#Aggiorniamo il numero di piante
	update Sezione
    set NumPiante = NumPiante -1
    where idSezione = @Sezione;
    
    #Individuiamo la Serra da cui va sottratto 1
	set @Serra = (
				select Serra
                from Sezione
                where idSezione = @Sezione
                );
	#Aggiorniamo il numero di piante
	update Serra
    set NumPiante = NumPiante -1
    where idSerra = @Serra;
end$$

delimiter ;


#Trigger che, all'eliminazione di un contenitore, aggiorna il numero di piante nelle serre e sezioni relative
drop trigger if exists AggiornaNumeroPianteDelete;

delimiter $$

create trigger AggiornaNumeroPianteDelete
after delete on Contenitore
for each row
begin
	#Individuiamo la Sezione interessata
	set @Sezione = (
				select Sezione
                from Ripiano
                where idRipiano = old.Ripiano
                );
	#Aggiorniamo il numero di piante
	update Sezione
    set NumPiante = NumPiante -1
    where idSezione = @Sezione;
    
    #Individuiamo la Serra da cui va sottratto 1
	set @Serra = (
				select Serra
                from Sezione
                where idSezione = @Sezione
                );
	#Aggiorniamo il numero di piante
	update Serra
    set NumPiante = NumPiante -1
    where idSerra = @Serra;
end$$

delimiter ;
#Trigger che, all'inserimento o all'aggiornamento della composizione di un settore/contenitore, chiamano una procedure che ricalcola
#la consistenza e la permeabilità del loro terreno.
#La procedure funziona così: 
# - Per prima cosa individua tutte le componenti con le relative percentuali;
# - Si effettua una media pesata, assegnando un valore numerico ai valori discreti che abbiamo preso come dominio di Consistenza e permeabilità;
# - Nello specifico, i valori si assegnano così:
#		- Per quanto riguarda la consistenza:				- Per quanto riguarda la permeabilità:
#			- Solida --> +2										- Alta --> +2
#			- SemiSolida --> +1									- Media --> +1
#			- Plastica --> -1									- Bassa --> 0
#			- Liquida --> -2									- MoltoBassa --> -1
#																- Impermeabile --> -2
#	Per effettuare la media pesata, si moltiplicano questi valori per la percentuale;
# - Ottenuta la somma finale, il terreno viene aggiornato così:
#		- Per quanto riguarda la consistenza:				- Per quanto riguarda la permeabilità:
#			- Fra 100 e 200 --> Solida							- fra 120 e 200 --> Alta
#			- Fra 0 e 99 --> SemiSolida							- fra 40 e 119 --> Media
#			- Fra -100 e -1 --> Plastica						- fra -40 e 39 --> Bassa
#			- Fra -200 e -101 --> Liquida						- fra -120 e -41 --> MoltoBassa
#																- fra -200 e -121 --> Impermeabile
drop trigger if exists TriggerAggiornaTerrenoSettoreInsert;
drop trigger if exists TriggerAggiornaTerrenoSettoreUpdate;
drop trigger if exists TriggerAggiornaTerrenoContenitoreInsert;
drop trigger if exists TriggerAggiornaTerrenoContenitoreUpdate;
drop procedure if exists ProcedureCalcoloTerrenoSettore;
drop procedure if exists ProcedureCalcoloTerrenoContenitore;

delimiter $$

create trigger TriggerAggiornaTerrenoSettoreInsert
after insert on ComposizioneSettore
for each row
begin
	call ProcedureCalcoloTerrenoSettore (new.Settore);
end $$

create trigger TriggerAggiornaTerrenoSettoreUpdate
after update on ComposizioneSettore
for each row
begin
	call ProcedureCalcoloTerrenoSettore (new.Settore);
end $$

create trigger TriggerAggiornaTerrenoContenitoreInsert
after insert on ComposizioneContenitore
for each row
begin
	call ProcedureCalcoloTerrenoContenitore (new.Contenitore);
end $$

create trigger TriggerAggiornaTerrenoContenitoreUpdate
after update on ComposizioneContenitore
for each row
begin
	call ProcedureCalcoloTerrenoContenitore (new.Contenitore);
end $$

create procedure ProcedureCalcoloTerrenoSettore (in _Settore int)
begin
	declare finito int default 0;
    declare ComponenteSingola varchar(45);
    declare SommaConsistenze int default 0;
    declare SommaPermeabilita int default 0;
    declare ComponentiSettore cursor for
		select Componente
        from ComposizioneSettore
        where Settore = _Settore;
	
    declare continue handler for
		not found set finito = 1;
    
    open ComponentiSettore;
    
    prelievo: loop
		fetch ComponentiSettore into ComponenteSingola;
        if (finito = 1) then
			leave prelievo;
        end if;
        
        #---------------------------------------------------------------------------------------
        #		MODIFICA CONSISTENZA
        #---------------------------------------------------------------------------------------
        
        #Per ogni componente valutiamo la sua consistenza e la sua percentuale
        set @ConsistenzaComponente = '';
        set @ConsistenzaComponente = (
										select Consistenza
                                        from Componente
                                        where idComponente = ComponenteSingola
                                        );       
		set @PercentualeComponente = (
										select Percentuale
                                        from ComposizioneSettore
                                        where Componente = ComponenteSingola and
											Settore = _Settore
                                            );
        
		#Come definito sopra, a seconda dei casi modifichiamo la somma totale delle consistenze
		if (@ConsistenzaComponente = 'Solida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * 2);
        elseif (@ConsistenzaComponente = 'SemiSolida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente);
        elseif (@ConsistenzaComponente = 'Plastica') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * -1);
		elseif (@ConsistenzaComponente = 'Liquida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * -2);
		end if;
        
        #---------------------------------------------------------------------------------------
        #		MODIFICA PERMEABILITA
        #---------------------------------------------------------------------------------------
		
        #Per ogni componente valutiamo la sua permeabilità
        set @PermeabilitaComponente = '';
        set @PermeabilitaComponente = (
										select Permeabilita
                                        from Componente
                                        where idComponente = ComponenteSingola
                                        );
        
		#Come definito sopra, a seconda dei casi modifichiamo la somma totale delle permeabilità
		if (@PermeabilitaComponente = 'Alta') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * 2);
        elseif (@PermeabilitaComponente = 'Media') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente);
        elseif (@PermeabilitaComponente = 'MoltoBassa') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * -1);
		elseif (@PermeabilitaComponente = 'Impermeabile') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * -2);
		end if;        
	end loop;
	
    #-------------------------------------------------------------------------------------------------
    #		VALUTAZIONI FINALI
    #-------------------------------------------------------------------------------------------------
	
    #Settiamo la consistenza finale
    set @ConsistenzaFinale = '';
    if (SommaConsistenze <= 200 and SommaConsistenze >= 100) then
		set @ConsistenzaFinale = 'Solida';
	elseif (SommaConsistenze < 100 and SommaConsistenze >= 0) then
		set @ConsistenzaFinale = 'SemiSolida';
	elseif  (SommaConsistenze < 0 and SommaConsistenze >= (-100))  then
		set @ConsistenzaFinale = 'Plastica';
	elseif  (SommaConsistenze < (-100) and SommaConsistenze >= (-200)) then
		set @ConsistenzaFinale = 'Liquida';
    end if;
	
    #Settiamo la permeabilita finale
    set @PermeabilitaFinale = '';
    if (SommaPermeabilita <= 200 and SommaPermeabilita >= 120) then
		set @PermeabilitaFinale = 'Alta';
	elseif (SommaPermeabilita < 120 and SommaPermeabilita >= 40) then
		set @PermeabilitaFinale = 'Media';
    elseif (SommaPermeabilita < 40 and SommaPermeabilita >= -40) then
		set @PermeabilitaFinale = 'Bassa';
	elseif (SommaPermeabilita < -40 and SommaPermeabilita >= -120) then
		set @PermeabilitaFinale = 'MoltoBassa';
	elseif (SommaPermeabilita < -120 and SommaPermeabilita >= -200) then
		set @PermeabilitaFinale = 'Impermeabile';
    end if;
    
    #Calcoliamo il pH del terreno
    set @PHTerreno = '';
    set @PHTerreno = ( 
						select T.pH
						from Settore S inner join Terreno T 
							on S.Terreno = T.idTerreno 
                        where S.idSettore = _Settore
                        );    
    
    #Verifichiamo se non esiste già un'occorrenza di terreno con queste proprietà, nel qual caso andiamo a fare una insert
    if (not exists (
					select *
					from terreno T 
					where T.pH = @PHTerreno and
						T.Permeabilita = @PermeabilitaFinale and
						T.Consistenza = @ConsistenzaFinale 
                        ))
	then 
		insert into Terreno (`Consistenza`,`Permeabilita`,`pH`) values
			(@ConsistenzaFinale, @PermeabilitaFinale, @PHTerreno);
    end if;
		
	#Aggiorniamo Settore inserendo nell'attributo "terreno" l'id del terreno con le proprietà cercate.
    if(@PHTerreno is null) then
		update Settore 
		set Terreno = ( 
						select T.idTerreno
						from Terreno T 
						where T.pH is null and
							T.Permeabilita = @PermeabilitaFinale and
							T.Consistenza = @ConsistenzaFinale 
						limit 1
							)
		where idSettore = _Settore ;
    else 
		update Settore 
		set Terreno = ( 
						select T.idTerreno
						from Terreno T 
						where T.pH = @PHTerreno and
							T.Permeabilita = @PermeabilitaFinale and
							T.Consistenza = @ConsistenzaFinale 
						limit 1
							)
		where idSettore = _Settore ;
	end if;
end $$

create procedure ProcedureCalcoloTerrenoContenitore (in _Contenitore int)
begin
	declare finito int default 0;
    declare ComponenteSingola varchar(45);
    declare SommaConsistenze int default 0;
    declare SommaPermeabilita int default 0;
    declare ComponentiContenitore cursor for
		select Componente
        from ComposizioneContenitore
        where Contenitore = _Contenitore;
	
    declare continue handler for
		not found set finito = 1;
    
    open ComponentiContenitore;
    
    prelievo: loop
		fetch ComponentiContenitore into ComponenteSingola;
        if (finito = 1) then
			leave prelievo;
        end if;
        
        #---------------------------------------------------------------------------------------
        #		MODIFICA CONSISTENZA
        #---------------------------------------------------------------------------------------
		
        #Per ogni componente valutiamo la sua consistenza e la sua percentuale
        set @ConsistenzaComponente = '';
        set @ConsistenzaComponente = (
										select Consistenza
                                        from Componente
                                        where idComponente = ComponenteSingola
                                        );
		set @PercentualeComponente = (
										select Percentuale
                                        from ComposizioneContenitore
                                        where Componente = ComponenteSingola and
											Contenitore = _Contenitore
                                            );
		#Come definito sopra, a seconda dei casi modifichiamo la somma totale delle consistenze
		if (@ConsistenzaComponente = 'Solida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * 2);
        elseif (@ConsistenzaComponente = 'SemiSolida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente);
        elseif (@ConsistenzaComponente = 'Plastica') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * -1);
		elseif (@ConsistenzaComponente = 'Liquida') then
			set SommaConsistenze = SommaConsistenze + (@PercentualeComponente * -2);
		end if;
        
        #---------------------------------------------------------------------------------------
        #		MODIFICA PERMEABILITA
        #---------------------------------------------------------------------------------------
		
        #Per ogni componente valutiamo la sua permeabilità
        set @PermeabilitaComponente = '';
        set @PermeabilitaComponente = (
										select Permeabilita
                                        from Componente
                                        where idComponente = ComponenteSingola
                                        );
		#Come definito sopra, a seconda dei casi modifichiamo la somma totale delle permeabilità
		if (@PermeabilitaComponente = 'Alta') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * 2);
        elseif (@PermeabilitaComponente = 'Media') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente);
        elseif (@PermeabilitaComponente = 'MoltoBassa') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * -1);
		elseif (@PermeabilitaComponente = 'Impermeabile') then
			set SommaPermeabilita = SommaPermeabilita + (@PercentualeComponente * -2);
		end if;
	end loop;
	
    #-------------------------------------------------------------------------------------------------
    #		VALUTAZIONI FINALI
    #-------------------------------------------------------------------------------------------------
	
    #Settiamo la consistenza finale
    set @ConsistenzaFinale = '';
    if (SommaConsistenze <= 200 and SommaConsistenze >= 100) then
		set @ConsistenzaFinale = 'Solida';
	elseif (SommaConsistenze < 100 and SommaConsistenze >= 0) then
		set @ConsistenzaFinale = 'SemiSolida';
	elseif  (SommaConsistenze < 0 and SommaConsistenze >= (-100))  then
		set @ConsistenzaFinale = 'Plastica';
	elseif  (SommaConsistenze < (-100) and SommaConsistenze >= (-200)) then
		set @ConsistenzaFinale = 'Liquida';
    end if;
	
    #Settiamo la permeabilita finale
    set @PermeabilitaFinale = '';
    if (SommaPermeabilita <= 200 and SommaPermeabilita >= 120) then
		set @PermeabilitaFinale = 'Alta';
	elseif (SommaPermeabilita < 120 and SommaPermeabilita >= 40) then
		set @PermeabilitaFinale = 'Media';
    elseif (SommaPermeabilita < 40 and SommaPermeabilita >= -40) then
		set @PermeabilitaFinale = 'Bassa';
	elseif (SommaPermeabilita < -40 and SommaPermeabilita >= -120) then
		set @PermeabilitaFinale = 'MoltoBassa';
	elseif (SommaPermeabilita < -120 and SommaPermeabilita >= -200) then
		set @PermeabilitaFinale = 'Impermeabile';
    end if;
    
    #Calcoliamo il pH del terreno
    set @PHTerreno = '';
    set @PHTerreno = ( 
						select T.pH
						from Contenitore C inner join Terreno T 
							on C.Terreno = T.idTerreno 
                        where C.idContenitore = _Contenitore
                        );    
    
    #Verifichiamo se non esiste già un'occorrenza di terreno con queste proprietà, nel qual caso andiamo a fare una insert
    if (not exists (
					select *
					from terreno T 
					where T.pH = @PHTerreno and
						T.Permeabilita = @PermeabilitaFinale and
						T.Consistenza = @ConsistenzaFinale 
                        ))
	then 
		insert into Terreno (`Consistenza`,`Permeabilita`,`pH`) values
			(@ConsistenzaFinale, @PermeabilitaFinale, @PHTerreno);
    end if;
		
	#Aggiorniamo Contenitore inserendo nell'attributo "terreno" l'id del terreno con le proprietà cercate
	if(@PHTerreno is null) then
		update Contenitore 
		set Terreno = ( 
						select T.idTerreno
						from Terreno T 
						where T.pH is null and
							T.Permeabilita = @PermeabilitaFinale and
							T.Consistenza = @ConsistenzaFinale 
						limit 1
							)
		where idContenitore = _Contenitore ;
    else 
		update Contenitore 
		set Terreno = ( 
						select T.idTerreno
						from Terreno T 
						where T.pH = @PHTerreno and
							T.Permeabilita = @PermeabilitaFinale and
							T.Consistenza = @ConsistenzaFinale 
						limit 1
							)
		where idContenitore = _Contenitore;
	end if;
end $$

DELIMITER ;

#Trigger che, nel momento in cui si crea un associazione fra un esemplare e un ordine, aggiorna il numero di piante nella serra,
#nella sezione e nel ripiano corrispondente
drop trigger if exists TriggerAggiornaNumeroPianteOrdine;

delimiter $$

create trigger TriggerAggiornaNumeroPianteOrdine
after insert on Relativo
for each row
begin
	#Individuiamo Ripiano, Sezione e Serra interessati
	set @Ripiano = (
						select Ripiano
                        from Contenitore
                        where Esemplare = new.Esemplare
                        );
	set @Sezione = (
						select Sezione
                        from Ripiano
                        where idRipiano = @Ripiano
                        );
	set @Serra = (
					select Serra
                    from Sezione
                    where idSezione = @Sezione
                    );
	#Aggiorniamo il relativo numero di piante    
    update Sezione
    set NumPiante = NumPiante - 1
    where idSezione = @Sezione;
    
    update Serra
    set NumPiante = NumPiante - 1
    where idSerra = @Serra;
end $$

delimiter ;
drop trigger if exists TriggerCalcolaDimensioneDataNascitaCosto;

delimiter $$

create trigger TriggerCalcolaDimensioneDataNascitaCosto
before insert on Esemplare
for each row
begin

	declare PrezzoBase double default 0;
	declare DimensioneBase double default 0;
    declare DimensioneAttuale double default 0;

	set PrezzoBase = (
		select P.CostoBase
		from Pianta P
		where P.idPianta = new.Pianta
		);
        


	set DimensioneBase  = (
		select P.DimMax
		from Pianta P
		where P.idPianta = new.Pianta
		);
        
	
	if(new.DataNascita is NULL)then
		set new.DataNascita = date(current_date()) ;
	end if;


	if(new.Dimensione is NULL) then
		call ProcedureCalcolaDimensioneEsemplare(new.DataNascita,new.Pianta, DimensioneAttuale);
        set new.Dimensione = DimensioneAttuale;
	end if;


	if(new.Prezzo is NULL)then
		set new.Prezzo = (new.Dimensione * PrezzoBase) / DimensioneBase ;
	end if;

end $$

delimiter ;

#Trigger che controlla se, all'inserimento di un nuovo contenitore in una sezione e in una serra,
#queste sono piene (ed eventualmente blocca l'inserimento)
drop trigger if exists ControllaNumeroPianteInsert;

delimiter $$

create trigger ControllaNumeroPianteInsert
before insert on Contenitore
for each row
begin
	#Troviamo la sezione e la serra interessate
	set @Sezione = (
						select Sezione
                        from Ripiano
                        where idRipiano = new.Ripiano
                        );
	set @Serra = (
					select Serra
                    from Sezione
                    where idSezione = @Sezione
                    );
	#vediamo qual è il numero di piante al momento
	set @NumPianteAttualeSezione = (
								select NumPiante
                                from Sezione
                                where idSezione = @Sezione
                                );
	set @NumPianteAttualeSerra = (
									select NumPiante
									from Serra
									where idSerra = @Serra
								);
	#Se è uguale al numero massimo di piante ospitabili, blocchiamo l'inserimento
	if(@NumPianteAttualeSezione = (
									select MaxPiante
									from Sezione
									where idSezione = @Sezione
								)) then
			signal sqlstate "45000"
            set message_text = 'ATTENZIONE: La sezione è già al completo';
	end if;
    if(@NumPianteAttualeSezione = (
									select MaxPiante
									from Serra
									where idSerra = @Serra
								)) then
			signal sqlstate "45000"
            set message_text = 'ATTENZIONE: La serra è già al completo';
	end if;
    
end $$

delimiter ;

drop trigger if exists ControllaNumeroPianteUpdate;

delimiter $$

create trigger ControllaNumeroPianteUpdate
before update on Contenitore
for each row
begin

#Troviamo la sezione e la serra interessate
	set @Sezione = (
						select Sezione
                        from Ripiano
                        where idRipiano = new.Ripiano
                        );
	set @Serra = (
					select Serra
                    from Sezione
                    where idSezione = @Sezione
                    );
	#vediamo qual è il numero di piante al momento
	set @NumPianteAttualeSezione = (
								select NumPiante
                                from Sezione
                                where idSezione = @Sezione
                                );
	set @NumPianteAttualeSerra = (
									select NumPiante
									from Serra
									where idSerra = @Serra
								);
	#Se è uguale al numero massimo di piante ospitabili, blocchiamo l'inserimento
	if(@NumPianteAttualeSezione = (
									select MaxPiante
									from Sezione
									where idSezione = @Sezione
								)) then
			signal sqlstate "45000"
            set message_text = 'ATTENZIONE: La sezione è già al completo';
	end if;
    if(@NumPianteAttualeSezione = (
									select MaxPiante
									from Serra
									where idSerra = @Serra
								)) then
			signal sqlstate "45000"
            set message_text = 'ATTENZIONE: La serra è già al completo';
	end if;



end $$

delimiter ;
#Trigger che controlla la credibilità di un utente quando questi inserisce un nuovo post o una nuova risposta;
#se la credibilità è pari a 0, blocca l'inserimento
drop trigger if exists TriggerControlloCredibilitaPost;
drop trigger if exists TriggerControlloCredibilitaRisposta;

delimiter $$

create trigger TriggerControlloCredibilitaPost
before insert on Post
for each row
begin
	set @CredibilitaUtente = (
								select Credibilita
                                from Account
                                where idAccount = new.Account
                                );
	if (@CredibilitaUtente <= 0) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Non hai la credibilità necessaria per aprire un nuovo post!';
    end if;
end $$

create trigger TriggerControlloCredibilitaRisposta
before insert on Risposta
for each row
begin
	set @CredibilitaUtente = (
								select Credibilita
                                from Account
                                where idAccount = new.Account
                                );
	if (@CredibilitaUtente <= 0) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Non hai la credibilità necessaria per creare una nuova risposta!';
    end if;
end $$


delimiter ;
#Trigger che, alla guarigione di un esemplare, controlla se c'è qualche ordine pendente per quella specie

drop trigger if exists TriggerControlloGuarigioneEsemplare;

delimiter $$

create trigger TriggerControlloGuarigioneEsemplare
after update on Esemplare
for each row
begin
	if(old.Malato = true and new.Malato = false) then
		call ProcedureAggiornamentoOrdinePendente(new.idEsemplare, new.Dimensione, new.Pianta);
    end if;
end $$

delimiter ;

#Con questo trigger controlliamo che l'utente, prima di inserire una pianta in un settore, abbia effettivamente completato quest'ultimo;
#Poiché si considera accettabile come forma per il settore qualsiasi poligono, consideriamo come numero minimo di punti necessario il numero 3
drop trigger if exists ControlloInserimentoPiantaSettore;

delimiter $$

create trigger ControlloInserimentoPiantaSettore
before insert on FormaPianta
for each row
begin
	#Il trigger consiste quindi di quest'unica query, che conta il numero di punti già inseriti relativamente a questo settore
	if(3>(
			select count(*)
            from Punto
            where Settore = new.Settore
            )) then
            signal sqlstate "45000"
            set message_text = 'ATTENZIONE: Completare il settore prima di inserire delle piante';
	end if;
end $$

delimiter ;

#Con questo trigger controlliamo che l'utente, prima di spostare una pianta in un settore, abbia effettivamente completato quest'ultimo;
#Poiché si considera accettabile come forma per il settore qualsiasi poligono, consideriamo come numero minimo di punti necessario il numero 3
drop trigger if exists ControlloInserimentoPiantaSettoreUpdate;

delimiter $$

create trigger ControlloInserimentoPiantaSettoreUpdate
before update on FormaPianta
for each row
begin
	#Il trigger consiste quindi di quest'unica query, che conta il numero di punti già inseriti relativamente a questo settore
	if(3>(
			select count(*)
            from Punto
            where Settore = new.Settore
            )) then
            signal sqlstate "45000"
            set message_text = 'ATTENZIONE: Completare il settore prima di inserire delle piante';
	end if;
end $$

delimiter ;

#Trigger che, all'inserimento di una misurazione, controlla che questa sia in linea con le esigenze delle piante
drop trigger if exists TriggerControlloMisurazioniAmbientaliEsigenze;
drop trigger if exists TriggerControlloMisurazioniContenitoreEsigenze;
drop trigger if exists TriggerControlloMisurazioniElementiEsigenze;

delimiter $$

create trigger TriggerControlloMisurazioniAmbientaliEsigenze
after insert on MisurazioneAmbientale
for each row
begin
	declare finito int default 0;
    declare PiantaSingola int;
    declare LuceSingola int;
    declare PianteSezione cursor for
		select distinct Pianta
        from Esemplare E inner join Contenitore C
			on E.idEsemplare = C.Esemplare
            inner join Ripiano R
            on R.idRipiano = C.Ripiano
        where R.Sezione = new.Sezione;
	declare continue handler for
		not found set finito = 1;
        
	open PianteSezione;
    
    prelievo: loop
		fetch PianteSezione into PiantaSingola;
        if (finito = 1) then
			leave prelievo;
        end if;
        
        #Controlliamo che la temperatura vada bene
        set @TempMax = (
							select TempMax
                            from Temperatura T inner join Esigenze E
								on T.idTemp = E.Temperatura
							where E.Pianta = PiantaSingola
                            );
		set @TempMin = (
							select TempMin
                            from Temperatura T inner join Esigenze E
								on T.idTemp = E.Temperatura
							where E.Pianta = PiantaSingola
                            );
		if (new.Temperatura > @TempMax or new.Temperatura < @TempMin) then
			set @Messaggio = 'ATTENZIONE: la pianta ';
            set @Messaggio = concat(@Messaggio, PiantaSingola);
            set @Messaggio = concat(@Messaggio, ' non può stare nella sezione ');
            set @Messaggio = concat(@Messaggio, new.Sezione);
            set @Messaggio = concat(@Messaggio, ' a causa della temperatura non adatta');
            signal sqlstate "45000"
            set message_text = @Messaggio;
        end if;
        
        #Controlliamo che la luminosità sia giusta
        set LuceSingola = (
							select if(L.Quantita = 'Bassa', @Quantita := 1,
									if(L.Quantita = 'Media', @Quantita := 3, @Quantita := 5)) * L.NumOre *
                                    if(L.Diretta = 1, 2, 1)
							from Luce L inner join Esigenze E
								on L.idLuce = E.LuceVegetativo  #Si considerano i periodi vegetativi perché sono quelli che richiedono pià cura
                            where E.Pianta = PiantaSingola
                            );
                            
		set @Luce = new.Illuminazione;
		
        case
			when @Luce is not null and @Luce = 'Bassa' then			
				if(LuceSingola > 20) then	
					set @Messaggio = 'ATTENZIONE: la pianta ';
					set @Messaggio = concat(@Messaggio, PiantaSingola);
					set @Messaggio = concat(@Messaggio, ' non può stare nella sezione ');
					set @Messaggio = concat(@Messaggio, new.Sezione);
					set @Messaggio = concat(@Messaggio, ' a causa della illuminazione non adatta');
					signal sqlstate "45000"
					set message_text = @Messaggio;
                end if;												
                
            when @Luce is not null and @Luce = 'Media' then		
				if(LuceSingola <= 20 or	
					LuceSingola > 80) then	
					set @Messaggio = 'ATTENZIONE: la pianta ';
					set @Messaggio = concat(@Messaggio, PiantaSingola);
					set @Messaggio = concat(@Messaggio, ' non può stare nella sezione ');
					set @Messaggio = concat(@Messaggio, new.Sezione);
					set @Messaggio = concat(@Messaggio, ' a causa della illuminazione non adatta');
					signal sqlstate "45000"
					set message_text = @Messaggio;		
                end if;
            
            when @Luce is not null and @Luce = 'Alta' then		
				if(LuceSingola <= 80) then 
					set @Messaggio = 'ATTENZIONE: la pianta ';
					set @Messaggio = concat(@Messaggio, PiantaSingola);
					set @Messaggio = concat(@Messaggio, ' non può stare nella sezione ');
					set @Messaggio = concat(@Messaggio, new.Sezione);
					set @Messaggio = concat(@Messaggio, ' a causa della illuminazione non adatta');
					signal sqlstate "45000"
					set message_text = @Messaggio;					
                end if;													
                
			else begin end;
        end case;
    end loop;
    
    close PianteSezione;
end $$


create trigger TriggerControlloMisurazioniContenitoreEsigenze
after insert on MisurazioneContenitore
for each row
begin
	declare AcquaSingola int;
	#Individuiamo di che specie si tratta
	set @Pianta = (
					select Pianta
					from Esemplare E inner join Contenitore C
						on E.idEsemplare = C.Esemplare
					where C.idContenitore = new.Contenitore
                );


    #Controlliamo se il pH va bene
    set @pH = (
				select pH
                from Terreno T inner join Esigenze E
					on T.idTerreno = E.Terreno
				where E.Pianta = @Pianta
                );

	
    if (@pH <> new.pH) then
		set @Messaggio = 'ATTENZIONE: Il contenitore ';
        set @Messaggio = concat(@Messaggio, new.Contenitore);
        set @Messaggio = concat(@Messaggio, ' ha un pH non adatto alla pianta ');
        set @Messaggio = concat(@Messaggio, @Pianta);
		signal sqlstate "45000"
        set message_text = @Pianta;
    end if;
    
    #Controlliamo se l'idratazione va bene
    set @AcquaVegetativo = (
								select if(A.Quantita = 'Basso', @Quantita := 1,
										if(A.Quantita = 'Medio', @Quantita := 3, @Quantita := 5)) * Periodicita
								from Acqua A inner join Esigenze E
									on A.idAcqua = E.AcquaVegetativo 
								where E.Pianta = @Pianta
                            );
	set @AcquaRiposo = (
								select if(A.Quantita = 'Basso', @Quantita := 1,
										if(A.Quantita = 'Medio', @Quantita := 3, @Quantita := 5)) * Periodicita
								from Acqua A inner join Esigenze E
									on A.idAcqua = E.AcquaRiposo
								where E.Pianta = @Pianta
                            );


	#Controlliamo il periodo in cui si trova la pianta
    if(exists(
				select *
                from CicliPianta CP inner join PeriodoCicli PC
					on CP.Periodo = PC.idPeriodo
				where PC.Vegetativo = true and
					month(current_date()) between PC.InizioPeriodo and PC.FinePeriodo
                    ))then
		set AcquaSingola = @AcquaVegetativo;
	else set AcquaSingola = @AcquaRiposo;
	end if;
                      
	#Controlliamo se l'idratazione è nella norma
	set @Acqua = new.Idratazione;
    
	case
		when @Acqua is not null and @Acqua = 'Bassa' then	
			if(AcquaSingola > 10) then	
				set @Messaggio = 'ATTENZIONE: Il contenitore ';
				set @Messaggio = concat(@Messaggio, new.Contenitore);
				set @Messaggio = concat(@Messaggio, ' ha una idratazione  non adatta alla pianta ');
				set @Messaggio = concat(@Messaggio, @Pianta);						
			end if;										
                
		when @Acqua is not null and @Acqua = 'Media' then		
			if(AcquaSingola <= 10 or	
				AcquaSingola > 25) then
				set @Messaggio = 'ATTENZIONE: Il contenitore ';
				set @Messaggio = concat(@Messaggio, new.Contenitore);
				set @Messaggio = concat(@Messaggio, ' ha una idratazione non adatta alla pianta ');
				set @Messaggio = concat(@Messaggio, @Pianta);						
			end if;
            
		when @Acqua is not null and @Acqua = 'Alta' then	
			if(AcquaSingola <= 25) then 
				set @Messaggio = 'ATTENZIONE: Il contenitore ';
				set @Messaggio = concat(@Messaggio, new.Contenitore);
				set @Messaggio = concat(@Messaggio, ' ha una idratazione non adatta alla pianta ');
				set @Messaggio = concat(@Messaggio, @Pianta);
			end if;			
            
		else begin end;
	end case;
end $$

create trigger TriggerControlloMisurazioniElementiEsigenze
after insert on PresenzaElemento
for each row
begin
	#Individuiamo di che specie si tratta
	set @Pianta = (
					select Pianta
					from Esemplare E inner join Contenitore C
						on E.idEsemplare = C.Esemplare
					where C.idContenitore = new.Contenitore
                );
	
    #Controlliamo se l'elemento misurato è necessario alla pianta
    if(new.Elemento not in(
							select Elemento
                            from EsigenzeElemento
                            where Pianta = @Pianta
                            ))then
		set @Messaggio = 'ATTENZIONE: Nel contenitore ';
        set @Messaggio = concat(@Messaggio, new.Contenitore);
        set @Messaggio = concat(@Messaggio, ' è presente l elemento ');
        set @Messaggio = concat(@Messaggio, new.Elemento);
        set @Messaggio = concat(@Messaggio, ' che non è fra le esigenze della pianta ');
        set @Messaggio = concat(@Messaggio, @Pianta);
        signal sqlstate "45000"
        set message_text = @Messaggio;
	end if;
    
    #Controlliamo se l'elemento si trova in quantità adatte alla pianta
    set @ConcentrazioneNecessaria = (
										select Concentrazione
                                        from EsigenzeElemento
                                        where Pianta = @Pianta and
											Elemento = new.Elemento
                                        );
	if(new.Quantita not between @ConcentrazioneNecessaria - 0.1*@ConcentrazioneNecessaria #Si dà un po' di margine per evitare di dover segnalare
		and @ConcentrazioneNecessaria + 0.1*@ConcentrazioneNecessaria) then						#ogni minima anomalia
		set @Messaggio = 'ATTENZIONE: Nel contenitore ';
        set @Messaggio = concat(@Messaggio, new.Contenitore);
        set @Messaggio = concat(@Messaggio, ' è presente l elemento ');
        set @Messaggio = concat(@Messaggio, new.Elemento);
        set @Messaggio = concat(@Messaggio, ' in quantità fuori dalla norma per la pianta ');
        set @Messaggio = concat(@Messaggio, @Pianta);
        signal sqlstate "45000"
        set message_text = @Messaggio;
    end if;
end $$

delimiter ;



#Questo trigger controlla la correttezza di un inserimento nella tabella "Acqua"

drop trigger if exists TriggerControlloValiditaAcquaInsert;

delimiter $$

create trigger TriggerControlloValiditaAcquaInsert
before insert on Acqua
for each row
begin
	#Questi sono i valori accettati
	if(new.Quantita<>'Bassa' and new.Quantita<>'Media' and new.Quantita<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Bassa", "Media", "Alta"';
	end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaAcquaUpdate;

delimiter $$

create trigger TriggerControlloValiditaAcquaUpdate
before update on Acqua
for each row
begin
	#Questi sono i valori accettati
	if(new.Quantita<>'Bassa' and new.Quantita<>'Media' and new.Quantita<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Bassa", "Media", "Alta"';
	end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Basato"
drop trigger if exists TriggerControlloValiditaBasato;

delimiter $$

create trigger TriggerControlloValiditaBasato
before insert on Basato
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Concentrazione<=0 and new.Concentrazione>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Concentrazione" è una percentuale!';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "Basato"
drop trigger if exists TriggerControlloValiditaBasatoUpdate;

delimiter $$

create trigger TriggerControlloValiditaBasatoUpdate
before update on Basato
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Concentrazione<=0 and new.Concentrazione>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Concentrazione" è una percentuale!';
    end if;
end $$

delimiter ;
#Questo trigger controlla la correttezza di un inserimento nella tabella "Componente"

drop trigger if exists TriggerControlloValiditaComponenteInsert;

delimiter $$

create trigger TriggerControlloValiditaComponenteInsert
before insert on Componente
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Consistenza"
	if (new.Consistenza is not null and new.Consistenza<>'Liquida' and new.Consistenza<>'Plastica' and 
		new.Consistenza<>'SemiSolida' and new.Consistenza<>'Solida')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di consistenza sono: "Liquida", "Plastica", "SemiSolida", "Solida" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "Permeabilita"
	if (new.Permeabilita is not null and new.Permeabilita<>'Alta' and new.Permeabilita<>'Media' and
		new.Permeabilita<>'Bassa' and new.Permeabilita<>'MoltoBassa' and new.Permeabilita<>'Impermeabile')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di permeabilita sono: "Alta", "Media", "Bassa", "MoltoBassa", "Impermeabile" oppure nessuno';
	end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaComponenteUpdate;

delimiter $$

create trigger TriggerControlloValiditaComponenteUpdate
before update on Componente
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Consistenza"
	if (new.Consistenza is not null and new.Consistenza<>'Liquida' and new.Consistenza<>'Plastica' and 
		new.Consistenza<>'SemiSolida' and new.Consistenza<>'Solida')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di consistenza sono: "Liquida", "Plastica", "SemiSolida", "Solida" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "Permeabilita"
	if (new.Permeabilita is not null and new.Permeabilita<>'Alta' and new.Permeabilita<>'Media' and
		new.Permeabilita<>'Bassa' and new.Permeabilita<>'MoltoBassa' and new.Permeabilita<>'Impermeabile')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di permeabilita sono: "Alta", "Media", "Bassa", "MoltoBassa", "Impermeabile" oppure nessuno';
	end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "ComposizioneContenitore"
drop trigger if exists TriggerControlloValiditaComposizioneContenitoreInsert;

delimiter $$

create trigger TriggerControlloValiditaComposizioneContenitoreInsert
before insert on ComposizioneContenitore
for each row
begin
	#Controlliamo prima la condizione sul dominio
	if (new.Percentuale<0 and new.Percentuale>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Questi non sono valori adatti per una percentuale!';
    end if;
    #Assicuriamoci poi che non si stia sforando con le percentuali
    set @PercentualeTotale = (
								select sum(Percentuale)
                                from ComposizioneContenitore
                                where Contenitore = new.Contenitore
                                );
	if(@PercentualeTotale + new.Percentuale > 100) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Stai sforando con i valori delle percentuali!';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "ComposizioneContenitore"
drop trigger if exists TriggerControlloValiditaComposizioneContenitoreUpdate;

delimiter $$

create trigger TriggerControlloValiditaComposizioneContenitoreUpdate
before update on ComposizioneContenitore
for each row
begin
	#Controlliamo la condizione sul dominio
	if (new.Percentuale<0 and new.Percentuale>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Questi non sono valori adatti per una percentuale!';
    end if;
    #Assicuriamoci poi che non si stia sforando con le percentuali
    set @PercentualeTotale = (
								select sum(Percentuale)
                                from ComposizioneContenitore
                                where Contenitore = new.Contenitore
                                );
	if(@PercentualeTotale + new.Percentuale - old.Percentuale > 100) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Stai sforando con i valori delle percentuali!';
    end if;
end $$

delimiter ;
#Trigger che controlla la validità di un inserimento nella tabella "ComposizioneSettore"
drop trigger if exists TriggerControlloValiditaComposizioneSettoreInsert;

delimiter $$

create trigger TriggerControlloValiditaComposizioneSettoreInsert
before insert on ComposizioneSettore
for each row
begin
	#Controlliamo prima la condizione sul dominio
	if (new.Percentuale<0 and new.Percentuale>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Questi non sono valori adatti per una percentuale!';
    end if;
    #Assicuriamoci poi che non si stia sforando con le percentuali
    set @PercentualeTotale = (
								select sum(Percentuale)
                                from ComposizioneSettore
                                where Settore = new.Settore
                                );
	if(@PercentualeTotale + new.Percentuale > 100) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Stai sforando con i valori delle percentuali!';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "ComposizioneSettore"
drop trigger if exists TriggerControlloValiditaComposizioneSettoreUpdate;

delimiter $$

create trigger TriggerControlloValiditaComposizioneSettoreUpdate
before update on ComposizioneSettore
for each row
begin
	#Controlliamo la condizione sul dominio
	if (new.Percentuale<0 and new.Percentuale>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Questi non sono valori adatti per una percentuale!';
    end if;
    #Assicuriamoci poi che non si stia sforando con le percentuali
    set @PercentualeTotale = (
								select sum(Percentuale)
                                from ComposizioneSettore
                                where Settore = new.Settore
                                );
	if(@PercentualeTotale + new.Percentuale - old.Percentuale > 100) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Stai sforando con i valori delle percentuali!';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "CondizioniFavorevoli"
drop trigger if exists TriggerControlloValiditaCondizioniFavorevoliInsert;

delimiter $$

create trigger TriggerControlloValiditaCondizioniFavorevoliInsert
before insert on CondizioniFavorevoli
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.Mese<12) or (new.Mese>=1) ) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi per Mese';
	end if;
    #Controlliamo la correttezza dell'attributo "Umidita"
    if (new.Umidita<=0 and new.Umidita>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Umidita" è una percentuale!';
    end if;
	#Controlliamo la correttezza dell'attributo "Illuminazione"
    if (new.Illuminazione is not null and new.Illuminazione<>'Bassa' and new.Illuminazione<>'Media' and new.Illuminazione<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Illuminazione" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
	#Controlliamo la correttezza dell'attributo "Idratazione"
	if (new.Idratazione is not null and new.Idratazione<>'Bassa' and new.Idratazione<>'Media' and new.Idratazione<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Idratazione" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
	#Controlliamo la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili per "pH" sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
    #Controlliamo la correttezza dell'attributo "Temperatura"
    if (new.Temperatura is not null and new.Temperatura<>'MoltoCaldo' and new.Temperatura<>'Caldo' and
		new.Temperatura<>'Medio' and new.Temperatura<>'Freddo' and new.Temperatura<>'MoltoFreddo')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Temperatura" sono: "MoltoCaldo", "Caldo", "Medio", "Freddo", "MoltoFreddo" oppure nessuno';
	end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaCondizioniFavorevoliUpdate;

delimiter $$

create trigger TriggerControlloValiditaCondizioniFavorevoliUpdate
before update on CondizioniFavorevoli
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.Mese<12) or (new.Mese>=1) ) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi per Mese';
	end if;
    #Controlliamo la correttezza dell'attributo "Umidita"
    if (new.Umidita<=0 and new.Umidita>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Umidita" è una percentuale!';
    end if;
	#Controlliamo la correttezza dell'attributo "Illuminazione"
    if (new.Illuminazione is not null and new.Illuminazione<>'Bassa' and new.Illuminazione<>'Media' and new.Illuminazione<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Illuminazione" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
	#Controlliamo la correttezza dell'attributo "Idratazione"
	if (new.Idratazione is not null and new.Idratazione<>'Bassa' and new.Idratazione<>'Media' and new.Idratazione<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Idratazione" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
	#Controlliamo la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili per "pH" sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
    #Controlliamo la correttezza dell'attributo "Temperatura"
    if (new.Temperatura is not null and new.Temperatura<>'MoltoCaldo' and new.Temperatura<>'Caldo' and
		new.Temperatura<>'Medio' and new.Temperatura<>'Freddo' and new.Temperatura<>'MoltoFreddo')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Temperatura" sono: "MoltoCaldo", "Caldo", "Medio", "Freddo", "MoltoFreddo" oppure nessuno';
	end if;
end $$

delimiter ;
#Trigger che controlla la validità di un inserimento nella tabella "Contenitore"
drop trigger if exists TriggerControlloValiditaContenitoreInsert;

delimiter $$

create trigger TriggerControlloValiditaContenitoreInsert
before insert on Contenitore
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Irrigazione is not null and new.Irrigazione<>'Bassa' and new.Irrigazione<>'Media' or new.Irrigazione<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "irrigazione" sono "Bassa", "Media", "Alta" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "Contenitore"
drop trigger if exists TriggerControlloValiditaContenitoreUpdate;

delimiter $$

create trigger TriggerControlloValiditaContenitoreUpdate
before update on Contenitore
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Irrigazione is not null and new.Irrigazione<>'Bassa' and new.Irrigazione<>'Media' or new.Irrigazione<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "irrigazione" sono "Bassa", "Media", "Alta" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "DiagnosiPossibili"
drop trigger if exists TriggerControlloValiditaDiagnosiPossibiliInsert;

delimiter $$

create trigger TriggerControlloValiditaDiagnosiPossibiliInsert
before insert on DiagnosiPossibili
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Attinenza<=0 and new.Attinenza>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Attinenza" è una percentuale!';
    end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaDiagnosiPossibiliUpdate;

delimiter $$

create trigger TriggerControlloValiditaDiagnosiPossibiliUpdate
before update on DiagnosiPossibili
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Attinenza<=0 and new.Attinenza>100)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: "Attinenza" è una percentuale!';
    end if;
end $$

delimiter ;
#Trigger che controlla la validità di un inserimento nella tabella "Elemento"
drop trigger if exists TriggerControlloValiditaElementoInsert;

delimiter $$

create trigger TriggerControlloValiditaElementoInsert
before insert on Elemento
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Dimensione<>'Micro' and new.Dimensione<>'Macro' and new.Dimensione<>'Meso' and new.Dimensione is not null)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "Micro", "Macro", "Meso" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un Aggiornamento nella tabella "Elemento"
drop trigger if exists TriggerControlloValiditaElementoUpdate;

delimiter $$

create trigger TriggerControlloValiditaElementoUpdate
before update on Elemento
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Dimensione<>'Micro' and new.Dimensione<>'Macro' and new.Dimensione<>'Meso' and new.Dimensione is not null)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "Micro", "Macro", "Meso" oppure nessuno';
    end if;
end $$

delimiter ;
#Questo trigger controlla la correttezza di un inserimento nella tabella "Giardino"; in più, inserisce il valore "Numero" relativamente
#ai giardini inseriti dallo stesso utente
drop trigger if exists TriggerControlloValiditaGiardinoInsert;

delimiter $$

create trigger TriggerControlloValiditaGiardinoInsert
before insert on Giardino
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Clima"
	if (new.Clima is not null and new.Clima<>'MoltoCaldo' and new.Clima<>'Caldo' and 
		new.Clima<>'Medio' and new.Clima<>'Freddo' and new.Clima<>'MoltoFreddo')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di clima sono: "MoltoCaldo", "Caldo", "Medio", "Freddo", "MoltoFreddo" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "IndiceManut"
	if (new.IndiceManut is not null and new.IndiceManut<>'Alto' and new.IndiceManut<>'Medio' and
		new.IndiceManut<>'Basso')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Alto", "Medio", "Basso" oppure nessuno';
	end if;
    #Infine, troviamo il valore da inserire in Numero
    set new.Numero = (
							select count(*)
                            from Giardino
                            where Account = new.Account
						) + 1;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un aggiornamento nella tabella "Giardino"
drop trigger if exists TriggerControlloValiditaGiardinoUpdate;

delimiter $$

create trigger TriggerControlloValiditaGiardinoUpdate
before update on Giardino
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Clima"
	if (new.Clima is not null and new.Clima<>'MoltoCaldo' and new.Clima<>'Caldo' and 
		new.Clima<>'Medio' and new.Clima<>'Freddo' and new.Clima<>'MoltoFreddo')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di clima sono: "MoltoCaldo", "Caldo", "Medio", "Freddo", "MoltoFreddo" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "IndiceManut"
	if (new.IndiceManut is not null and new.IndiceManut<>'Alto' and new.IndiceManut<>'Medio' and
		new.IndiceManut<>'Basso')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Alto", "Medio", "Basso" oppure nessuno';
	end if;
end $$

delimiter ;
#Questo trigger controlla la correttezza di un inserimento nella tabella "Luce"
drop trigger if exists TriggerControlloValiditaLuceInsert;

delimiter $$

create trigger TriggerControlloValiditaLuceInsert
before insert on Luce
for each row
begin
	#Questi sono i valori accettati
	if(new.Quantita<>'Bassa' and new.Quantita<>'Media' and new.Quantita<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Bassa", "Media", "Alta"';
	end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un aggiornamento nella tabella "Luce"
drop trigger if exists TriggerControlloValiditaLuceUpdate;

delimiter $$

create trigger TriggerControlloValiditaLuceUpdate
before update on Luce
for each row
begin
	#Questi sono i valori accettati
	if(new.Quantita<>'Bassa' and new.Quantita<>'Media' and new.Quantita<>'Alta') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Bassa", "Media", "Alta"';
	end if;
end $$

delimiter ;


#Questo trigger controlla la correttezza di un inserimento nella tabella "MisurazioneAmbientale"
drop trigger if exists TriggerControlloValiditaMisurazioneAmbientaleInsert;

delimiter $$

create trigger TriggerControlloValiditaMisurazioneAmbientaleInsert
before insert on MisurazioneAmbientale
for each row
begin
    #Controlliamo la correttezza dell'attributo "Permeabilita"
	if (new.Illuminazione is not null and new.Illuminazione<>'Alta' and new.Illuminazione<>'Media' and
		new.Illuminazione<>'Bassa')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di illuminazione sono: "Alta", "Media", "Bassa" oppure nessuno';
	end if;
     #Controlliamo la correttezza dell'attributo "Umidita"
	if (new.Umidita>100 or new.Umidita<0)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: L umidità è calcolata in percentuale!';
	end if;
end $$

#Questo trigger controlla la correttezza di un inserimento nella tabella "MisurazioneAmbientale"

delimiter ;

drop trigger if exists TriggerControlloValiditaMisurazioneAmbientaleUpdate;

delimiter $$

create trigger TriggerControlloValiditaMisurazioneAmbientaleUpdate
before update on MisurazioneAmbientale
for each row
begin
    #Controlliamo la correttezza dell'attributo "Permeabilita"
    if (new.Illuminazione is not null and new.Illuminazione<>'Alta' and new.Illuminazione<>'Media' and
        new.Illuminazione<>'Bassa')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di illuminazione sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
     #Controlliamo la correttezza dell'attributo "Umidita"
    if (new.Umidita>100 or new.Umidita<0)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: L umidità è calcolata in percentuale!';
    end if;
end $$

delimiter ;


#Questo trigger controlla la correttezza di un inserimento nella tabella "MisurazioneContenitore"
drop trigger if exists TriggerControlloValiditaMisurazioneContenitoreInsert;

delimiter $$

create trigger TriggerControlloValiditaMisurazioneContenitoreInsert
before insert on MisurazioneContenitore
for each row
begin
    #Controlliamo la correttezza dell'attributo "Idratazione"
	if (new.Idratazione is not null and new.Idratazione<>'Alta' and new.Idratazione<>'Media' and
		new.Idratazione<>'Bassa')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di dratazione sono: "Alta", "Media", "Bassa" oppure nessuno';
	end if;
     #Controlliamo poi la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di pH sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un aggiornamento nella tabella "MisurazioneContenitore"
drop trigger if exists TriggerControlloValiditaMisurazioneContenitoreUpdate;

delimiter $$

create trigger TriggerControlloValiditaMisurazioneContenitoreUpdate
before update on MisurazioneContenitore
for each row
begin
    #Controlliamo la correttezza dell'attributo "Idratazione"
	if (new.Idratazione is not null and new.Idratazione<>'Alta' and new.Idratazione<>'Media' and
		new.Idratazione<>'Bassa')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di dratazione sono: "Alta", "Media", "Bassa" oppure nessuno';
	end if;
     #Controlliamo poi la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di pH sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
end $$

delimiter ;
#Trigger che controlla che esista un periodo in cui è possibile effettuare una potatura su una data pianta nel momento
#in cui la andiamo a definire come necessaria a quella pianta
USE `progettouni`;

DELIMITER $$

DROP TRIGGER IF EXISTS progettouni.ControlloValiditaNecessitaPotaturaInsert$$
USE `progettouni`$$
CREATE DEFINER=`root`@`localhost` TRIGGER `progettouni`.`ControlloValiditaNecessitaPotaturaInsert` BEFORE INSERT ON `necessitapotatura` FOR EACH ROW
BEGIN
	#Deve esistere un periodo in cui è possibile effettuare questa potatura
	if not exists (
		select *
		from periodopotatura 
		where Pianta = new.Pianta and
			TipoPotatura = new.TipoPotatura )
	then 
		signal sqlstate "45000"
        set message_text = 'Non esiste un periodo in cui è possibile effettuare questo tipo di potatura su questa pianta ! ';
	end if;
    
END$$

DROP TRIGGER IF EXISTS progettouni.ControlloValiditaNecessitaPotaturaUpdate$$
USE `progettouni`$$
CREATE DEFINER=`root`@`localhost` TRIGGER `progettouni`.`ControlloValiditaNecessitaPotaturaUpdate` BEFORE UPDATE ON `necessitapotatura` FOR EACH ROW
BEGIN
	#Deve esistere un periodo in cui è possibile effettuare questa potatura
	if not exists (
		select *
		from periodopotatura 
		where Pianta = new.Pianta and
			TipoPotatura = new.TipoPotatura )
	then 
		signal sqlstate "45000"
        set message_text = 'Non esiste un periodo in cui è possibile effettuare questo tipo di potatura su questa pianta ! ';
	end if;
    
END$$
DELIMITER ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoAttacchiInsert;

delimiter $$

create trigger TriggerControlloValiditaPeriodoAttacchiInsert
before insert on PeriodoAttacchi
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Una probabilità non può essere maggiore del 100%
    if(new.Probabilita>100) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: La probabilità di un attacco non può essere maggiore del 100%';
    end if;
end $$

delimiter ;


#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoAttacchiUpdate;

delimiter $$

create trigger TriggerControlloValiditaPeriodoAttacchiUpdate
before update on PeriodoAttacchi
for each row
begin
    #I periodi sono sempre considerati in mesi
    if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
    end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Una probabilità non può essere maggiore del 100%
    if(new.Probabilita>100) then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: La probabilità di un attacco non può essere maggiore del 100%';
    end if;
end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi;
#inoltre controlliamo la correttezza dell'attributo Fio/Fru
drop trigger if exists TriggerControlloValiditaPeriodoCicliInsert;

delimiter $$

create trigger TriggerControlloValiditaPeriodoCicliInsert
before insert on PeriodoCicli
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Questi sono i valori possibili per Fio/Fru
    if(new.Fio_Fru<>'Fioritura' and new.Fio_Fru<>'Fruttificazione' and new.Fio_Fru<>'Entrambi' and new.Fio_Fru<>'Nessuno') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Fioritura", "Fruttificazione", "Entrambi", "Nessuno"';
    end if;
    
    #Controlliamo che se il periodo è vegetativo, allora non può essere di fioritura/fruttificazione
    if(new.Vegetativo = false and new.Fio_Fru <> 'Nessuno') then
    	signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Un periodo può essere di fioritura/fruttificazione solo se è vegetativo';
    end if;

end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi;
#inoltre controlliamo la correttezza dell'attributo Fio/Fru
drop trigger if exists TriggerControlloValiditaPeriodoCicliUpdate;

delimiter $$

create trigger TriggerControlloValiditaPeriodoCicliUpdate
before update on PeriodoCicli
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Questi sono i valori possibili per Fio/Fru
    if(new.Fio_Fru<>'Fioritura' and new.Fio_Fru<>'Fruttificazione' and new.Fio_Fru<>'Entrambi' and new.Fio_Fru<>'Nessuno') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Fioritura", "Fruttificazione", "Entrambi", "Nessuno"';
    end if;
   #Controlliamo che se il periodo è vegetativo, allora non può essere di fioritura/fruttificazione
    if(new.Vegetativo = false and (new.FIo_Fru = 'Fioritura') or (new.FIo_Fru = 'Fruttificazione') or (new.Fio_Fru = 'Entrambi')) then
    	signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Un periodo può essere di fioritura/fruttificazione solo se è vegetativo';
    end if;


end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoNonUtilizzoInsert;

delimiter $$

create trigger TriggerControlloValiditaPeriodoNonUtilizzoInsert
before insert on PeriodoNonUtilizzo
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Controlliamo che questo periodo non si sovrapponga ad un altro
    if exists (	
				select *
                from PeriodoNonUtilizzo
                where Prodotto = new.Prodotto and
                    ((FinePeriodo >= new.InizioPeriodo and
                    FinePeriodo <= new.FinePeriodo ) or
                    (InizioPeriodo >= new.InizioPeriodo and
                    InizioPeriodo <= new.FinePeriodo )))
                    then
                    signal sqlstate "45000"
					set message_text = 'Esiste già un occorrenza di questo prodotto in questo periodo dell anno ';
	end if;
end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoNonUtilizzoUpdate;

delimiter $$

create trigger TriggerControlloValiditaPeriodoNonUtilizzoUpdate
before update on PeriodoNonUtilizzo
for each row
begin
    #I periodi sono sempre considerati in mesi
    if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
    end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
    #Controlliamo che questo periodo non si sovrapponga ad un altro
    if exists ( 
                select *
                from PeriodoNonUtilizzo
                where Prodotto = new.Prodotto and
                    ((FinePeriodo >= new.InizioPeriodo and
                    FinePeriodo <= new.FinePeriodo ) or
                    (InizioPeriodo >= new.InizioPeriodo and
                    InizioPeriodo <= new.FinePeriodo )))
                    then
                    signal sqlstate "45000"
                    set message_text = 'Esiste già un occorrenza di questo prodotto in questo periodo dell anno ';
    end if;
end $$

delimiter ;

USE `progettouni`;

DELIMITER $$
#Trigger con cui si controlla la validità di un inserimento in PeriodoPotatura
DROP TRIGGER IF EXISTS progettouni.TriggerControlloValiditaPeriodoPotaturaInsert$$
USE `progettouni`$$
CREATE DEFINER=`root`@`localhost` TRIGGER `progettouni`.`TriggerControlloValiditaPeriodoPotaturaInsert` BEFORE INSERT ON `periodopotatura` FOR EACH ROW
BEGIN
    #I valori di InizioPeriodo e FinePeriodo sono mesi, quindi sono accettati solo valori fra 1 e 12
    if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<1) or (new.FinePeriodo<1)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;  
    #Non si accettano neanche Periodi del tipo "Ottobre - Febbraio"
	IF (New.InizioPeriodo > New.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'I periodi che sono a cavallo dell anno vanno inseriti separatamente ';
    end if;
    #Controllo che i periodi non si sovrappongono
    if exists (	
				select *
                from PeriodoPotatura 
                where Pianta = new.Pianta and
					TipoPotatura = new.TipoPotatura and 
                    ((FinePeriodo >= new.InizioPeriodo and
                    FinePeriodo <= new.FinePeriodo ) or
                    (InizioPeriodo >= new.InizioPeriodo and
                    InizioPeriodo <= new.FinePeriodo )))
                    then
                    signal sqlstate "45000"
					set message_text = 'Esiste già un occorrenza di questa potatura per questa pianta in questo periodo dell anno ';
	end if;
    
END$$
DELIMITER ;


DELIMITER $$
#Trigger con cui si controlla la validità di un aggiornamento in PeriodoPotatura
DROP TRIGGER IF EXISTS progettouni.TriggerControlloValiditaPeriodoPotaturaUpdate$$
USE `progettouni`$$
CREATE DEFINER=`root`@`localhost` TRIGGER `progettouni`.`TriggerControlloValiditaPeriodoPotaturaUpdate` BEFORE UPDATE ON `periodopotatura` FOR EACH ROW
BEGIN
    #I valori di InizioPeriodo e FinePeriodo sono mesi, quindi sono accettati solo valori fra 1 e 12
    if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<1) or (new.FinePeriodo<1)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;  
    #Non si accettano neanche Periodi del tipo "Ottobre - Febbraio"
	IF (New.InizioPeriodo > New.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'I periodi che sono a cavallo dell anno vanno inseriti separatamente ';
    end if;
    #Controllo che i periodi non si sovrappongono
    if exists (	
				select *
                from PeriodoPotatura 
                where Pianta = new.Pianta and
					TipoPotatura = new.TipoPotatura and 
                    ((FinePeriodo >= new.InizioPeriodo and
                    FinePeriodo <= new.FinePeriodo ) or
                    (InizioPeriodo >= new.InizioPeriodo and
                    InizioPeriodo <= new.FinePeriodo )))
                    then
                    signal sqlstate "45000"
					set message_text = 'Esiste già un occorrenza di questa potatura per questa pianta in questo periodo dell anno ';
	end if;
    
END$$
DELIMITER ;


#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoRinvasiInsert;

delimiter $$

create trigger TriggerControlloValiditaPeriodoRinvasiInsert
before insert on PeriodoRinvasi
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaPeriodoRinvasiUpdate;

delimiter $$

create trigger TriggerControlloValiditaPeriodoRinvasiUpdate
before update on PeriodoRinvasi
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
    if(new.InizioPeriodo>new.FinePeriodo) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I periodi a cavallo dell anno vanno inseriti separatamente';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Preferenze"
drop trigger if exists TriggerControlloValiditaPreferenzeInsert;

delimiter $$

create trigger TriggerControlloValiditaPreferenzeInsert
before insert on Preferenze
for each row
begin
	#Controlliamo la correttezza dell'attributo "Dimensione"
	if (new.Dimensione is not null and new.Dimensione<>'MoltoPiccola' and new.Dimensione<>'Piccola' 
		and new.Dimensione<>'Media' and new.Dimensione<>'Grande' and new.Dimensione<>'MoltoGrande')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valore di "Dimensione" non accettato';
	end if;
    #Controlliamo la correttezza dell'attributo "Costo"
	if (new.Costo is not null and new.Costo<>'MoltoEconomica' and new.Costo<>'Economica' and new.Costo<>'NellaMedia'
		and new.Costo<>'Costosa' and new.Costo<>'MoltoCostosa')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valore di "Costo" non accettato';
	end if;
    #Controlliamo la correttezza dell'attributo "Temperatura"
    if (new.Temp is not null and new.Temp<>'MoltoFreddo' and new.Temp<>'Freddo' 
		and new.Temp<>'Medio' and new.Temp<>'Caldo' and new.Temp<>'MoltoCaldo')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valore di "Temperatura" non accettato';
    end if;
    #Controlliamo la correttezza dell'attributo "Luce"
    if (new.Luce is not null and new.Luce<>'Bassa' and new.Luce<>'Media' and new.Luce<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Luce" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Acqua"
    if (new.Acqua is not null and new.Acqua<>'Bassa' and new.Acqua<>'Media' and new.Acqua<>'Alta')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Acqua" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "IndiceManut"
    if (new.IndiceManut is not null and new.IndiceManut<>'Basso' and new.IndiceManut<>'Medio' and new.IndiceManut<>'Alto')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "IndiceManut" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpDimensione"
    if (new.ImpDimensione is not null and new.ImpDimensione<=0 and new.ImpDimensione>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpDimensione" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpDioica"
    if (new.ImpDioica is not null and new.ImpDioica<=0 and new.ImpDioica>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpDioica" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpInfestante"
    if (new.ImpInfestante is not null and new.ImpInfestante<=0 and new.ImpInfestante>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpInfestante" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpTemperatura"
    if (new.ImpTemp is not null and new.ImpTemp<=0 and new.ImpTemp>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpTemperatura" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpSempreverde"
    if (new.ImpSempreverde is not null and new.ImpSempreverde<=0 and new.ImpSempreverde>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpSempreverde" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpCosto"
    if (new.ImpCosto is not null and new.ImpCosto<=0 and new.ImpCosto>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpCosto" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpLuce"
    if (new.ImpLuce is not null and new.ImpLuce<=0 and new.ImpLuce>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpLuce" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpAcqua"
    if (new.ImpAcqua is not null and new.ImpAcqua<=0 and new.ImpAcqua>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpAcqua" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpTerreno"
    if (new.ImpTerreno is not null and new.ImpTerreno<=0 and new.ImpTerreno>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpTerreno" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpIndiceManut"
    if (new.ImpIndiceManut is not null and new.ImpIndiceManut<=0 and new.ImpIndiceManut>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpIndiceManut" vanno da 1 a 10';
    end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaPreferenzeUpdate;

delimiter $$

create trigger TriggerControlloValiditaPreferenzeUpdate
before update on Preferenze
for each row
begin
    #Controlliamo la correttezza dell'attributo "Dimensione"
    if (new.Dimensione is not null and new.Dimensione<>'MoltoPiccola' and new.Dimensione<>'Piccola' 
        and new.Dimensione<>'Media' and new.Dimensione<>'Grande' and new.Dimensione<>'MoltoGrande')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Dimensione" sono: "MoltoGrande", "Grande", "Media", "Piccola", "MoltoPiccola" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Costo"
    if (new.Costo is not null and new.Costo<>'MoltoEconomica' and new.Costo<>'Economica' and new.Costo<>'NellaMedia'
        and new.Costo<>'Costosa' and new.Costo<>'MoltoCostosa')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Costo" sono: "MoltoEconomica", "Economica", "NellaMedia", "Costosa", "MoltoCostosa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Temperatura"
    if (new.Temp is not null and new.Temp<>'MoltoFreddo' and new.Temp<>'Freddo' 
        and new.Temp<>'Medio' and new.Temp<>'Caldo' and new.Temp<>'MoltoCaldo')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Temperatura" sono: "MoltoFreddo", "Freddo", "Medio", "Caldo", "MoltoCaldo" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Luce"
    if (new.Luce is not null and new.Luce<>'Bassa' and new.Luce<>'Media' and new.Luce<>'Alta')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Luce" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Acqua"
    if (new.Acqua is not null and new.Acqua<>'Bassa' and new.Acqua<>'Media' and new.Acqua<>'Alta')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Acqua" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "IndiceManut"
    if (new.IndiceManut is not null and new.IndiceManut<>'Basso' and new.IndiceManut<>'Medio' and new.IndiceManut<>'Alto')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "IndiceManut" sono: "Alta", "Media", "Bassa" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpDimensione"
    if (new.ImpDimensione is not null and new.ImpDimensione<=0 and new.ImpDimensione>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpDimensione" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpDioica"
    if (new.ImpDioica is not null and new.ImpDioica<=0 and new.ImpDioica>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpDioica" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpInfestante"
    if (new.ImpInfestante is not null and new.ImpInfestante<=0 and new.ImpInfestante>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpInfestante" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpTemperatura"
    if (new.ImpTemp is not null and new.ImpTemp<=0 and new.ImpTemp>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpTemperatura" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpSempreverde"
    if (new.ImpSempreverde is not null and new.ImpSempreverde<=0 and new.ImpSempreverde>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpSempreverde" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpCosto"
    if (new.ImpCosto is not null and new.ImpCosto<=0 and new.ImpCosto>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpCosto" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpLuce"
    if (new.ImpLuce is not null and new.ImpLuce<=0 and new.ImpLuce>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpLuce" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpAcqua"
    if (new.ImpAcqua is not null and new.ImpAcqua<=0 and new.ImpAcqua>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpAcqua" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpTerreno"
    if (new.ImpTerreno is not null and new.ImpTerreno<=0 and new.ImpTerreno>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpTerreno" vanno da 1 a 10';
    end if;
    #Controlliamo la correttezza dell'attributo "ImpIndiceManut"
    if (new.ImpIndiceManut is not null and new.ImpIndiceManut<=0 and new.ImpIndiceManut>10)then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "ImpIndiceManut" vanno da 1 a 10';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "PreferenzePeriodi"
drop trigger if exists TriggerControlloValiditaPreferenzePeriodiInsert;

delimiter $$

create trigger TriggerControlloValiditaPreferenzePeriodiInsert
before insert on PreferenzePeriodi
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Importanza<=0 and new.Importanza>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Importanza" vanno da 1 a 10';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "PreferenzePeriodi"
drop trigger if exists TriggerControlloValiditaPreferenzePeriodiUpdate;

delimiter $$

create trigger TriggerControlloValiditaPreferenzePeriodiUpdate
before update on PreferenzePeriodi
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Importanza<=0 and new.Importanza>10)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Importanza" vanno da 1 a 10';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Prodotto"
drop trigger if exists TriggerControlloValiditaProdottoInsert;

delimiter $$

create trigger TriggerControlloValiditaProdottoInsert
before insert on Prodotto
for each row
begin
	#Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Tipo is not null and new.Tipo<>'Selettivo' and new.Tipo<>'AmpioSpettro')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Tipo" sono: "Selettivo", "AmpioSpettro" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Modalita is not null and new.Modalita<>'Irrigazione' and new.Modalita<>'Nebulizzazione' and new.Modalita<>'Entrambe')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Modalita" sono: "Irrigazione", "Nebulizzazione", "Entrambe" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Prodotto"
drop trigger if exists TriggerControlloValiditaProdottoUpdate;

delimiter $$

create trigger TriggerControlloValiditaProdottoUpdate
before update on Prodotto
for each row
begin
	#Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Tipo is not null and new.Tipo<>'Selettivo' and new.Tipo<>'AmpioSpettro')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Tipo" sono: "Selettivo", "AmpioSpettro" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Modalita is not null and new.Modalita<>'Irrigazione' and new.Modalita<>'Nebulizzazione' and new.Modalita<>'Entrambe')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Modalita" sono: "Irrigazione", "Nebulizzazione", "Entrambe" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che, all'inserimento di un'occorrenza di quantità, controlla che l'elemento inserito sia effettivamente
#utilizzato da quel tipo di concimazione
drop trigger if exists TriggerControlloValiditaQuantitaElementoPerConcimazioneInsert;

delimiter $$

create trigger TriggerControlloValiditaQuantitaElementoPerConcimazioneInsert
before insert on QuantitaElementoPerConcimazione
for each row
begin
	#L'unico controllo da fare è che il tipo di concimazione interessato utilizzi l'elemento presente nella insert
	if(not exists(
		select *
        from UtilizzoElemento
        where TipoConcimazione = new.Concimazione and
			Elemento = new.Elemento
            ))then
        set @Messaggio = 'ATTENZIONE: La concimazione numero ';
        set @Messaggio = concat(@Messaggio, new.Concimazione);
        set @Messaggio = concat(@Messaggio, ' non utilizza l elemento ');
        set @NomeElemento = (
								select Nome
                                from Elemento
                                where idElemento = new.Elemento
                                );
        set @Messaggio = concat(@Messaggio, @NomeElemento);
        signal sqlstate "45000"
        set message_text = @messaggio;
    end if;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaQuantitaElementoPerConcimazioneUpdate;

delimiter $$

create trigger TriggerControlloValiditaQuantitaElementoPerConcimazioneUpdate
before update on QuantitaElementoPerConcimazione
for each row
begin
	#L'unico controllo da fare è che il tipo di concimazione interessato utilizzi l'elemento presente nella insert
	if(not exists(
		select *
        from UtilizzoElemento
        where TipoConcimazione = new.Concimazione and
			Elemento = new.Elemento
            ))then
        set @Messaggio = 'ATTENZIONE: La concimazione numero ';
        set @Messaggio = concat(@Messaggio, new.Concimazione);
        set @Messaggio = concat(@Messaggio, ' non utilizza l elemento ');
        set @NomeElemento = (
								select Nome
                                from Elemento
                                where idElemento = new.Elemento
                                );
        set @Messaggio = concat(@Messaggio, @NomeElemento);
        signal sqlstate "45000"
        set message_text = @messaggio;
    end if;
end $$

delimiter ;

#Trigger che, all'inserimento di un report di diagnostica, controlla che non ci siano stati errori nel sistema (nello specifico controlla la
#ridondanza presente nel report)

drop trigger if exists TriggerControlloValiditaReportDiagnostica;

delimiter $$

create trigger TriggerControlloValiditaReportDiagnostica
before insert on ReportDiagnostica
for each row
begin
	#Ciò che dobbiamo controllare è la corrispondenza fra la sezione indicata dal report e la sezione in cui si trova l'esemplare coinvolto
	set @SezioneEsemplare = (
								select Sezione
                                from Ripiano R inner join Contenitore C
									on R.idRipiano = C.Ripiano
								where C.Esemplare = new.Esemplare
                                );
	if(@SezioneEsemplare <> new.Sezione) then
		set @Messaggio = 'ATTENZIONE: Si è verificato un errore nelle misurazioni interne al report di diagnostica riguardante l esemplare numero ';
        set @Messaggio = concat(@Messaggio, new.Esemplare);
        signal sqlstate "45000"
        set message_text = @Messaggio;
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Scheda"
drop trigger if exists TriggerControlloValiditaSchedaInsert;

delimiter $$

create trigger TriggerControlloValiditaSchedaInsert
before insert on Scheda
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Collocazione is not null and new.Collocazione<>'PienaTerra' and new.Collocazione<>'Vaso')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "PienaTerra", "Vaso" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "Scheda"
drop trigger if exists TriggerControlloValiditaSchedaUpdate;

delimiter $$

create trigger TriggerControlloValiditaSchedaUpdate
before update on Scheda
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Collocazione is not null and new.Collocazione<>'PienaTerra' and new.Collocazione<>'Vaso')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "PienaTerra", "Vaso" oppure nessuno';
    end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un inserimento nella tabella "Settore"
drop trigger if exists TriggerControlloValiditaSettoreInsert;

delimiter $$

create trigger TriggerControlloValiditaSettoreInsert
before insert on Settore
for each row
begin
	#Controlliamo la correttezza dell'attributo "DirCardinale"
	if (new.DirCardinale is not null and new.DirCardinale<>'Nord' and new.DirCardinale<>'Est' 
		and new.DirCardinale<>'Sud' and new.DirCardinale<>'Ovest')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "DirCardinale" sono: "Nord", "Sud", "Est", "Ovest" oppure nessuno';
	end if;
    #Controlliamo la correttezza dell'attributo "Base"
    if (new.Base is null and new.Base<>'PienaTerra' and new.Base<>'Pavimento')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "Base" sono: "PienaTerra", "Pavimento" oppure nessuno';
    end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un inserimento nella tabella "Settore"
drop trigger if exists TriggerControlloValiditaSettoreUpdate;

delimiter $$

create trigger TriggerControlloValiditaSettoreUpdate
before update on Settore
for each row
begin
	#Controlliamo la correttezza dell'attributo "DirCardinale"
	if (new.DirCardinale is not null and new.DirCardinale<>'Nord' and new.DirCardinale<>'Est' 
		and new.DirCardinale<>'Sud' and new.DirCardinale<>'Ovest')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "DirCardinale" sono: "Nord", "Sud", "Est", "Ovest" oppure nessuno';
	end if;
    #Controlliamo la correttezza dell'attributo "Base"
    if (new.Base is null and new.Base<>'PienaTerra' and new.Base<>'Pavimento')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili di "Base" sono: "PienaTerra", "Pavimento" oppure nessuno';
    end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un inserimento nella tabella "Temperatura"
drop trigger if exists TriggerControlloValiditaTemperaturaInsert;

delimiter $$

create trigger TriggerControlloValiditaTemperaturaInsert
before insert on Temperatura
for each row
begin
	#Questa è l'unica condizione da controllare
	if(new.TempMin > new.TempMax) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: La temperatura minima deve essere minore di quella masssima';
	end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un aggiornamento nella tabella "Temperatura"
drop trigger if exists TriggerControlloValiditaTemperaturaUpdate;

delimiter $$

create trigger TriggerControlloValiditaTemperaturaUpdate
before update on Temperatura
for each row
begin
	#Questa è l'unica condizione da controllare
	if(new.TempMin > new.TempMax) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: La temperatura minima deve essere minore di quella masssima';
	end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un inserimento nella tabella "Terreno"
drop trigger if exists TriggerControlloValiditaTerrenoInsert;

delimiter $$

create trigger TriggerControlloValiditaTerrenoInsert
before insert on Terreno
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Consistenza"
	if (new.Consistenza is not null and new.Consistenza<>'Liquida' and new.Consistenza<>'Plastica' and 
		new.Consistenza<>'SemiSolida' and new.Consistenza<>'Solida')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Liquida", "Plastica", "SemiSolida", "Solida" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "Permeabilita"
	if (new.Permeabilita is not null and new.Permeabilita<>'Alta' and new.Permeabilita<>'Media' and
		new.Permeabilita<>'Bassa' and new.Permeabilita<>'MoltoBassa' and new.Permeabilita<>'Impermeabile')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Alta", "Media", "Bassa", "MoltoBassa", "Impermeabile" oppure nessuno';
	end if;
     #Controlliamo infine la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
end $$

delimiter ;

#Questo trigger controlla la correttezza di un inserimento nella tabella "Terreno"
drop trigger if exists TriggerControlloValiditaTerrenoUpdate;

delimiter $$

create trigger TriggerControlloValiditaTerrenoUpdate
before update on Terreno
for each row
begin
	#Controlliamo prima la correttezza dell'attributo "Consistenza"
	if (new.Consistenza is not null and new.Consistenza<>'Liquida' and new.Consistenza<>'Plastica' and 
		new.Consistenza<>'SemiSolida' and new.Consistenza<>'Solida')then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Liquida", "Plastica", "SemiSolida", "Solida" oppure nessuno';
    end if;
    #Controlliamo quindi la correttezza dell'attributo "Permeabilita"
	if (new.Permeabilita is not null and new.Permeabilita<>'Alta' and new.Permeabilita<>'Media' and
		new.Permeabilita<>'Bassa' and new.Permeabilita<>'MoltoBassa' and new.Permeabilita<>'Impermeabile')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "Alta", "Media", "Bassa", "MoltoBassa", "Impermeabile" oppure nessuno';
	end if;
     #Controlliamo infine la correttezza dell'attributo "pH"
	if (new.pH is not null and new.pH<>'FortementeAcido' and new.pH<>'Acido' and new.pH<>'SubAcido'
		and new.pH='Neutro' and new.pH='SubBasico' and new.pH='Basico' and new.pH='Alcalino')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Gli unici valori possibili sono: "FortementeAcido", "Acido", "SubAcido", "Neutro", "SubBasico", "Basico", "Alcalino" oppure nessuno';
	end if;
end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaTipoConcimazioneInsert;

delimiter $$

create trigger TriggerControlloValiditaTipoConcimazioneInsert
before insert on TipoConcimazione
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
end $$

delimiter ;

#In maniera simile al TriggerControlloValiditaPeriodoPotatura, anche qui facciamo gli stessi controlli sui periodi
drop trigger if exists TriggerControlloValiditaTipoConcimazioneUpdate;

delimiter $$

create trigger TriggerControlloValiditaTipoConcimazioneUpdate
before update on TipoConcimazione
for each row
begin
	#I periodi sono sempre considerati in mesi
	if((new.InizioPeriodo>12) or (new.FinePeriodo>12) or (new.InizioPeriodo<0) or (new.FinePeriodo<0)) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valori non validi (i periodi sono considerati in mesi)';
	end if;
end $$

delimiter ;

#Trigger che, all'inserimento di un intervento di concimazione, controlla che sia possibile effettuarla in quel momento
drop trigger if exists TriggerControlloValiditaTipoInterventoConcimazione;

delimiter $$

create trigger TriggerControlloValiditaTipoInterventoConcimazione
before insert on TipoInterventoConcimazione
for each row
begin
	#Individuiamo il mese in cui l'intervento viene effettuato
	set @DataIntervento = (
							select month(Data)
                            from Intervento
                            where idIntervento = new.Intervento
                            );
	#Individuiamo i mesi in cui è possibile effettuare la concimazione
    set @MeseInizio = (
						select month(InizioPeriodo)
                        from TipoConcimazione
                        where idConcimazione = new.TipoConcimazione
                        );
	set @MeseFine = (
						select month(FinePeriodo)
                        from TipoConcimazione
                        where idConcimazione = new.TipoConcimazione
                        );
	#Controlliamo che il vincolo sia rispettato
    if((@DataIntervento < @MeseInizio) or (@DataIntervento > @MeseFine))then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Non è possibile effettuare questa concimazione in questo periodo!';
	end if;
end $$

delimiter ;

#Trigger che, all'inserimento di un intervento di potatura, controlla che sia possibile effettuarla in quel momento
drop trigger if exists TriggerControlloValiditaTipoInterventoPotatura;

delimiter $$

create trigger TriggerControlloValiditaTipoInterventoPotatura
before insert on TipoInterventoPotatura
for each row
begin
	#Individuiamo il mese in cui l'intervento viene effettuato
	set @DataIntervento = (
							select month(Data)
                            from Intervento
                            where idIntervento = new.Intervento
                            );
	#Individuiamo la specie di appartenenza dell'esemplare oggetto dell'intervento
    set @PiantaAppartenenza = (
								select P.idPianta
                                from Pianta P inner join Esemplare E
									on P.idPianta = E.Pianta
                                    inner join Intervento I
                                    on E.idEsemplare = I.Esemplare
								where I.idIntervento = new.Intervento
							);
	#Controlliamo che il vincolo sia rispettato
    if(not exists(
				select *
                from PeriodoPotatura
                where TipoPotatura = new.TipoPotatura and
					Pianta = @PiantaAppartenenza and
					@DataIntervento between InizioPeriodo and FinePeriodo
                    ))then
		set @Messaggio = 'ATTENZIONE: Non è possibile effettuare la potatura ';
        set @Messaggio = concat(@Messaggio, new.TipoPotatura);
        set @Messaggio = concat(@Messaggio, ' sulla pianta ');
        set @NomePianta = (
							select Nome
                            from Pianta
                            where idPianta = @PiantaAppartenenza
                            );
        set @Messaggio = concat(@Messaggio, @NomePianta);
        set @Messaggio = concat(@Messaggio, ' in questo periodo!'); 
		signal sqlstate "45000"
        set message_text = @Messaggio;
	end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "UtilizzoElemento"
drop trigger if exists TriggerControlloValiditaUtilizzoElementoInsert;

delimiter $$

create trigger TriggerControlloValiditaUtilizzoElementoInsert
before insert on UtilizzoElemento
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Modalita<>'Disciolto' and new.Modalita<>'Nebulizzato' and new.Modalita is not null)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "Disciolto", "Nebulizzato" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "UtilizzoElemento"
drop trigger if exists TriggerControlloValiditaUtilizzoElementoUpdate;

delimiter $$

create trigger TriggerControlloValiditaUtilizzoElementoUpdate
before update on UtilizzoElemento
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Modalita<>'Disciolto' and new.Modalita<>'Nebulizzato' and new.Modalita is not null)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: gli unici valori possibili sono: "Disciolto", "Nebulizzato" oppure nessuno';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Intervento" e ne calcola entità e costo (qualora questi non siano specificati)
#Il calcolo (approssimativo) di entità e costo viene effettuato come segue, in base alle dimensioni dell'esemplare
#al tipo di intervento. Nello specifico, le due valutazioni verranno effettuate così:
# - Si assegna un valore in base al tipo di intervento
# - Questo valore viene moltiplicato per la dimensione dell'esemplare divisa per due
# - Quest'ultimo valore ci dà l'entità dell'intervento
# - L'entità moltiplicata per 5 restituisce il costo.
#Da notare che gli addetti potrebbero modificare tali valori dopo un sopralluogo
drop trigger if exists TriggerControlloValiditaValutazioneCostoEntitaInterventoInsert;

delimiter $$

create trigger TriggerControlloValiditaValutazioneCostoEntitaInterventoInsert
before insert on Intervento
for each row
begin
	declare EntitaIntervento int default 0;
    declare DimensioneEsemplare double;
	#Controlliamo la correttezza dell'attributo "Motivo"
	if (new.Motivo is not null and new.Motivo<>'Richiesta' and new.Motivo<>'Programmato' and new.Motivo<>'Automatico') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valore di "Motivo" non accettato';
    end if;
    #Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Tipo is not null and new.Tipo<>'Trattamento' and new.Tipo<>'Potatura' and new.Tipo<>'Concimazione'
		and new.Tipo<>'Piantumazione' and new.Tipo<>'Rinvaso' and new.Tipo<>'Altro')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Valore di "Tipo" non accettato';
	end if;
    #Procediamo ora al calcolo di entità e costo
    #La valutazione rispetto al tipo di intervento viene valutata come segue
    if(new.Tipo = 'Concimazione') then
		set EntitaIntervento = 1;
	elseif (new.Tipo = 'Rinvaso' or new.Tipo = 'Piantumazione' or new.Tipo = 'Trattamento') then
		set EntitaIntervento = 3;
	elseif (new.Tipo = 'Potatura') then
		set EntitaIntervento = 5;
	end if;
    #Calcoliamo la dimensione dell'esemplare in questione
    set @DataNascita = (
							select DataNascita
                            from Esemplare
                            where idEsemplare = new.Esemplare
                            );
    set @PiantaEsemplare = (
    						select Pianta
    						from Esemplare
    						where idEsemplare = new.Esemplare
    						);

    call ProcedureCalcolaDimensioneEsemplare(@DataNascita, @PiantaEsemplare, DimensioneEsemplare);
	#Aggiorniamo il valore dell'entità
    set new.Entita = EntitaIntervento*DimensioneEsemplare;
    #Aggiorniamo il valore del costo
    set new.Costo = new.Entita * 5;
end $$

delimiter ;

drop trigger if exists TriggerControlloValiditaInterventoUpdate;

delimiter $$
#Questo trigger non ricalcola né costo né entità, in quanto si suppone che queste possano essere cambiate dallo staffo se necessario
create trigger TriggerControlloValiditaInterventoUpdate
before update on Intervento
for each row
begin
	#Controlliamo la correttezza dell'attributo "Motivo"
	if (new.Motivo is not null and new.Motivo<>'Richiesta' and new.Motivo<>'Programmato') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Motivo" sono: "Richiesta", "Programmato" oppure nessuno';
    end if;
    #Controlliamo la correttezza dell'attributo "Tipo"
	if (new.Tipo is not null and new.Tipo<>'Trattamento' and new.Tipo<>'Potatura' and new.Tipo<>'Concimazione'
		and new.Tipo<>'Piantumazione' and new.Tipo<>'Rinvaso' and new.Tipo<>'Altro')then
        signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I valori possibili per "Tipo" sono: "Trattamento", "Potatura", "Piantumazione", "Rinvaso", "Altro" oppure nessuno';
	end if;
end $$

delimiter ;

#Trigger che controlla la validità di un inserimento nella tabella "Voto"
drop trigger if exists TriggerControlloValiditaVotoInsert;

delimiter $$

create trigger TriggerControlloValiditaVotoInsert
before insert on Voto
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Giudizio not between 1 and 5)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I voti vanno da 1 a 5';
    end if;
end $$

delimiter ;

#Trigger che controlla la validità di un aggiornamento nella tabella "Voto"
drop trigger if exists TriggerControlloValiditaVotoUpdate;

delimiter $$

create trigger TriggerControlloValiditaVotoUpdate
before update on Voto
for each row
begin
	#Questa è l'unica condizione da controllare
	if (new.Giudizio not between 1 and 5)then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: I voti vanno da 1 a 5';
    end if;
end $$

delimiter ;

#Trigger che, nel momento in cui un ordine diventa 'Evaso', crea una nuova scheda relativamente all'utente e agli esemplari interessati
drop trigger if exists TriggerCreazioneNuovaScheda;

delimiter $$

create trigger TriggerCreazioneNuovaScheda
after update on Ordine
for each row
begin
	declare EsemplareIns int;
    declare DimensioneDaInserire int;
    declare PiantaDaInserire int;
    declare finito int default 0;
	#Recuperiamo gli Esemplari per cui creare una scheda
    declare EsemplariDaInserire cursor for
		select Esemplare
		from Relativo
		where Ordine = new.idOrdine;
	
    declare continue handler 
		for not found set finito = 1;
        
	#IL trigger deve procedere solo se il nuovo stato dell'ordine è 'Evaso'
	if(new.Stato = 'Evaso') then
		#Calcoliamo la data dell'ordine
		set @DataDaInserire = str_to_date(new.Timestamp, '%Y%m%d');
        
        open EsemplariDaInserire;
        
        #Per ogni esemplare da inserire, ne troviamo la dimensione, la specie d'appartenenza e la dimensione
        prelievo: loop
        fetch EsemplariDaInserire into EsemplareIns;
        if(finito = 1) then
			leave prelievo;
		end if;
        set DimensioneDaInserire = (
										select Dimensione
										from Esemplare
										where idEsemplare = EsemplareIns
										);
		set PiantaDaInserire = (
									select P.Nome
                                    from 
										Esemplare E inner join Pianta P
											on E.Pianta = P.idPianta
                                    where E.idEsemplare = EsemplareIns
                                    );
		#Infine inizializziamo la scheda
		insert into Scheda (`DataAcquisto`, `DimAcquisto`, `NomePianta`, `Esemplare`, `Account`) values
        (@DataDaInserire, DimensioneDaInserire, PiantaDaInserire, EsemplareIns, new.Account);
        end loop;
        
        close EsemplariDaInserire;
    end if;
end $$

delimiter ;

#Trigger che, all'inserimento di un nuovo esemplare, crea una nuova occorrenza di contenitore in cui inserisce il terreno e l'irrigazione più
#adatti all'esemplare (eventualmente possono poi venir modificati dall'azienda); da notare che è comunque compito degli addetti indicare la
#composizione effettiva del terreno.
drop trigger if exists TriggerDistribuzioneEsemplare;
drop procedure if exists ProcedureAggiornamentoOrdinePendente;

delimiter $$

create trigger TriggerDistribuzioneEsemplare
after insert on Esemplare
for each row
begin
	declare SerraPiuLibera int;
    declare SezionePiuLibera int;
    declare RipianoPiuLibero int;
    declare TerrenoPiuAdatto int;
    declare PeriodoEsemplare int;
    declare IrrigazionePiuAdatta varchar(45);
    #Troviamo la serra più libera
    set SerraPiuLibera = (
							select idSerra
                            from Serra
                            where (MaxPiante - NumPiante) >= all (
																	select (MaxPiante -NumPiante)
                                                                    from Serra
                                                                    )
							limit 1
						);
	#Troviamo la sezione più libera all'interno di quella serra
	set SezionePiuLibera = (
								select idSezione
                                from Sezione
                                where Serra = SerraPiuLibera and
									(MaxPiante - NumPiante) >= all (
																		select (MaxPiante - NumPiante)
                                                                        from Sezione
                                                                        where Serra = SerraPiuLibera
                                                                        )
								limit 1
							);
	#Troviamo il ripiano più libero all'interno di quella sezione (si suppone che i ripiani abbiano spazio per lo stesso numero di piante)
	set RipianoPiuLibero = (
								select idRipiano
                                from Contenitore C right outer join Ripiano R
									on C.Ripiano = R.idRipiano
                                where R.Sezione = SezionePiuLibera
                                group by idRipiano
                                having count(*) <= all (
														select count(*)
                                                        from Contenitore C1 right outer join Ripiano R1
																on C1.Ripiano = R1.idRipiano
                                                        where R1.Sezione = SezionePiuLibera
                                                        group by R1.idRipiano
                                                        )
								limit 1
							);
	#Controlliamo che ci sia effettivamente posto
    if (RipianoPiuLibero is null) then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: è finito lo spazio nelle serre';
    end if;
	#Individuiamo il terreno più adatto a quella pianta
	set TerrenoPiuAdatto = (
								select Terreno
                                from Esigenze
                                where Pianta = new.Pianta
                                );
	#Individuiamo il periodo in cui si trova la pianta
	set PeriodoEsemplare = (
								select Vegetativo
                                from PeriodoCicli PC inner join CicliPianta CP
									on PC.idPeriodo = CP.Periodo
								where CP.Pianta = new.Pianta and
									month(current_date())>=PC.InizioPeriodo and
                                    month(current_date())<=PC.FinePeriodo
							);
	#A seconda del periodo in cui si trova la pianta, decidiamo il livello di irrigazione
	if(PeriodoEsemplare = 0)then
		set IrrigazionePiuAdatta = (
										select Quantita
                                        from Acqua A inner join Esigenze E
											on A.idAcqua = E.AcquaRiposo
                                        where E.Painta = new.Pianta
									);
	elseif (PeriodoEsemplare = 1) then
		set IrrigazionePiuAdatta = (
										select Quantita
                                        from Acqua A inner join Esigenze E
											on A.idAcqua = E.AcquaVegetativo
                                        where E.Painta = new.Pianta
									);
	end if;
	insert into Contenitore (`Ripiano`, `Esemplare`, `Terreno`, `Irrigazione`, `Superficie`) values
		(RipianoPiuLibero, new.idEsemplare, TerrenoPiuAdatto, IrrigazionePiuAdatta, new.Dimensione);
	#Controlliamo che non ci sia pendenza per questa specie di pianta ed eventualmente chiamiamo una procedure apposita
	if(exists(
		select *
		from Pendente
		where Pianta = new.Pianta
	   ))then
       call ProcedureAggiornamentoOrdinePendente (new.idEsemplare, new.Dimensione, new.Pianta);         
	end if;
end $$


create procedure ProcedureAggiornamentoOrdinePendente(in EsemplareDaVendere int, in DimensioneDaInserire double, in PiantaPendente int)
begin
	declare OrdineDaAggiornare int;
    #Aggiorniamo l'attributo venduto in esemplare
    update Esemplare
    set venduto = true
    where idEsemplare = EsemplareDaVendere;
    #Individuiamo l'ordine pendente
    set OrdineDaAggiornare = (
								select idOrdine
                                from Pendente
                                where Pianta = PiantaPendente
                                limit 1
                                );
	#Vediamo quanti erano gli esemplari mancanti
	set @EsemplariMancanti = (
								select Quantita
                                from Pendente
                                where Ordine = OrdineDaAggiornare and
									Pianta = PiantaPendente
								);
	#Aggiorniamo la tabella 'Pendente'
	if(@EsemplariMancanti = 1) then
		delete 
        from Pendente
        where Ordine = OrdineDaAggiornare and
			Pianta = PiantaPendente;
	elseif(@EsemplariMancanti > 1) then
		update Pendente
        set Quantita = Quantita - 1
        where Ordine = OrdineDaAggiornare and
			Pianta = PiantaPendente;
	end if;
    #Creiamo un'occorrenza di relativo
    insert into Relativo (`Ordine`, `Esemplare`) values
			(OrdineDaAggiornare, EsemplareDaVendere);
	#Creiamo infine la nuova scheda
    set @DataDaInserire = (
							select date(Timestamp)
                            from Ordine
                            where idOrdine = OrdineDaAggiornare
                            );
	set @PiantaDaInserire = (
							select Nome
                            from Pianta
                            where idPianta = PiantaPendente
                            );
	set @AccountOrdine = (
							select Account
                            from Ordine
                            where idOrdine = OrdineDaAggiornare
							);
    insert into Scheda (`DataAcquisto`, `DimAcquisto`, `NomePianta`, `Esemplare`, `Account`) values
        (@DataDaInserire, DimensioneDaInserire, @PiantaDaInserire, EsemplareDaVendere, @AccountOrdine);
end $$
delimiter ;



#Trigger che, all'inserimento di una nuova occorrenza in "Contrasto", lo blocca se chimico = false per l'agente corrispondente
drop trigger if exists TriggerControlloValiditaContrasto;

delimiter $$

create trigger TriggerControlloValiditaContrasto
before insert on Contrasto
for each row
begin
	set @Chimico = (
					select Chimico
                    from Agente
                    where idAgente = new.Agente
                    );
	if (@Chimico = false) then
		set @Messaggio = 'ATTENZIONE: l agente ';
        set @Messaggio = concat(@Messaggio, new.Agente);
        set @Messaggio = concat(@Messaggio, 'non è vulnerabile alla lotta chimica');
		signal sqlstate "45000"
        set message_text = @Messaggio;
    end if;
end $$

delimiter ;


#Trigger che, all'inserimento di un'occorrenza in "UtilizzoProdotto", controlla che l'intervento in questione sia effettivamente un trattamento

drop trigger if exists TriggerControlloValiditaUtilizzoProdottoInsert;

delimiter $$

create trigger TriggerControlloValiditaUtilizzoProdottoInsert
before insert on UtilizzoProdotto
for each row
begin
	set @Tipo = (
					select Tipo
                    from Intervento
                    where idIntervento = new.Intervento
                    );
	if (@Tipo <> 'Trattamento') then
		signal sqlstate "45000"
        set message_text = 'ATTENZIONE: Puoi inserire qui solo se l intervento è un trattamento';
    end if;
end $$

delimiter ;