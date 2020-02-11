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
		where I.Data < current_date() + interval 15 year and
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
	
    
    
    #Effettuiamo un ranking in base al punteggio (considerando gli interventi per città) e andiamo ad inserire nella materialized view
    insert into InterventiInGiornata
		select D.Intervento,
			D.Citta,
            D.Entita,
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
        where D.EntitaTot < 100;
        
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
