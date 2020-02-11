

#Function che, date due piante, calcola la distanza minima a cui queste devono trovarsi affinché non entrino in competizione per gli elementi
#nel terreno o per la luce.
#Il calcolo funziona così:
# - Si prende la dimensione delle 2 piante, eventualmente moltiplicata per 5 se la pianta è infestante, e si fa la somma (questo rappresenta 
#	essenzialmente il conflitto in termini di luce)
# - Per ogni elemento necessario in comune, si prende la quantità necessaria maggiore fra quella delle due piante e si moltiplica per la dimensione
#   della pianta più grande divisa per 10 (questo rappresenta il conflitto per gli elementi; le cifre sono scelte così che, per due piante nella media,
#   la distanza aumenta di circa 10 centimetri per ogni elemento)

drop function if exists FunctionCalcoloDistanzaMinima;

delimiter $$

create function FunctionCalcoloDistanzaMinima(PiantaUno int, PiantaDue int)
returns double not deterministic
begin
	#Cominciamo col calcolare la distanza necessaria ad evitare conflitti in termini di luce
	set @Distanza = (
						select if( Infestante = true, DimMax * 5, DimMax)
                        from Pianta
                        where idPianta = PiantaUno
                            );
	set @Distanza = @Distanza +
					(
						select if(Infestante = true, DimMax * 5, DimMax)
                        from Pianta
                        where idPianta = PiantaDue
                            );
	#Individuiamo la dimensione più grande fra quella delle due piante (dato che servirà dopo)
	set @DimMaggiore = 0.1 * (
								select max(DimMax)
								from Pianta
								where idPianta = PiantaUno or
									idPianta = PiantaDue
                                );
	#Aggiungiamo il seguente valore, rappresentante i conflitti per elementi in comune
    set @Distanza = @Distanza +
					(
						select sum(if(E.Concetrazione > E1.Concentrazione, E.Concetrazione, E1.Concentrazione))*@DimMaggiore
                        from EsigenzeElemento E inner join EsigenzeElement E1
							on (E.Elemento = E1.Elemento)
                        where E.Pianta = PiantaUno and
							E1.Pianta = PiantaDue
					);
	return @Distanza;
end $$

delimiter ;



#Data una pianta, il suo indice di manutenzione viene calcolato tenendo in considerazione la probabilità di subire attacchi, di avere carenze di elementi o acqua, di essere esposta a temperature non tollerate, nonché in base al numero di potature e concimazioni già previste dall’azienda. 
#Il calcolo effettivo, effettuato dalla seguente funzione, avviene nel seguente modo:
#Detto I l'indice di manutenzione, si pone I = PC + PE + PA + PT, dove:
# - PC rappresenta il numero di concimazioni necessarie alla pianta diviso 10
# - PE rappresenta la probabilità di avere carenze di elementi e si calcola sommando gli elementi necessitati dalla pianta divisi per 10
# - PA rappresenta la probabilità di avere carenze di acqua e si calcola prendendo la periodicità delle annaffiature (su 10 giorni) divisa per 10
# - PT rappresenta la probabilità di essere esposta a temperature non tollerabili e si calcola ponendo 10/range accettato (TempMax - TempMin)
# - Si somma ad I il numero di potature e trattamenti necessari in un anno (i trattamenti necessari sono quelli preventivi contro gli agenti per cui
#	esistono periodi nei quali la probabilità di subire attacchi supera il 50%
# - Si divide I per l’indice di accrescimento (in generale le piante che crescono più lentamente sono più complesse e necessitano cure più particolari)


drop function if exists FunctionCalcoloIndiceManutenzione;

delimiter $$

create function FunctionCalcoloIndiceManutenzione (_Pianta int)
returns double not deterministic
begin
	declare IndiceGenerale double default 0;
    #Inizializziamo l'indice con le necessità riguardanti le concimazioni
    set IndiceGenerale = 0.01 * (
									select count(*)
                                    from EsigenzeConcimazione
                                    where Pianta = _Pianta
                                    );
    #Aggiungiamo all'indice le necessità di acqua
    set IndiceGenerale = IndiceGenerale +
						0.1 * (
							select A.Periodicita
                            from Acqua A inner join Esigenze E
								on A.idAcqua = E.AcquaVegetativo #Si è scelto qui di considerare il periodo vegetativo perché è quello che richiede più cure
							where E.Pianta = _Pianta
                            ) * 1.5; #Per passare da una periodicità settimale ad una su 10 giorni si fa quest'approssimazione
    #Inseriamo nel conto gli elementi necessitati
    set IndiceGenerale = IndiceGenerale +
						(
							select count(*)
                            from EsigenzeElemento
                            where Pianta = _Pianta
                            ) * 0.1;
	#Aggiungiamo le necessità di temperatura
    set IndiceGenerale = IndiceGenerale +
						10/(
							select (T.TempMax - T.TempMin)
                            from Temperatura T inner join Esigenze E
								on T.idTemp = E.Temperatura
							where E.Pianta = _Pianta
                            );
	#Aggiungiamo poi le potature
    set IndiceGenerale = IndiceGenerale +
						(
							select sum(Quantita)
                            from NecessitaPotatura
                            where Pianta = _Pianta
                            );
	#Aggiungiamo il numero di trattamenti che saranno necessari alla pianta
    set IndiceGenerale = IndiceGenerale +
						(
							select count(*)
                            from PeriodoAttacchi
                            where Pianta = _Pianta and
								Probabilita > 50
                            );
	#Dividiamo infine per l'indice di accrescimento (si considera quello aereo)
    set @IndiceDiAccrescimento = (
									select F.CrescitaAerea
                                    from Famiglia F inner join Pianta P
										on F.idFamiglia = P.Famiglia
									where P.idPianta = _Pianta
                                    );
	set IndiceGenerale = IndiceGenerale / @IndiceDiAccrescimento;
    
    #Possiamo ora restituire il valore
    return IndiceGenerale;
end $$

delimiter ;


#Function che, dato l'account e il numero di un giardino ne restituisce il preventivo
drop function if exists FunctionCalcoloPreventivoGiardino;

delimiter $$

#Il costo viene calcolato semplicemente in base al costo base delle piante presenti
create function FunctionCalcoloPreventivoGiardino(NumGiardino int, AccountGiardino int)
returns double not deterministic
begin
	set @Preventivo = (
						select sum(CostoBase)
                        from Pianta P inner join FormaPianta FP
							on P.idPianta = FP.Pianta
                            inner join Settore S
                            on FP.Settore = S.idSettore
						where S.NumeroGiardino = NumGiardino and
							S.AccountGiardino = AccountGiardino
                            );
	if(@Preventivo is null) then
		set @Preventivo = 0;
    end if;
	return @Preventivo;
end $$

delimiter ;

