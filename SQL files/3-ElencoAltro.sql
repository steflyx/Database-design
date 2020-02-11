#Qui si crea una materialized view in cui vengono registrate tutte le sezioni dedicate alla quarantena di esemplari malati; per scegliere la sezione,
#si prende quella più piccola fra quelle che possono ospitare almeno 1/80 degli esemplari totali della serra (stima sulla percentuale di esemplari malati)

drop table if exists MV_SezioniIsolamento;

create table MV_SezioniIsolamento(
    Serra int not null,
    Sezione int null,
    primary key (Serra)
)Engine = InnoDB default charset = latin1;

insert into MV_SezioniIsolamento
	select S.idSerra,
		SE.idSezione
    from Serra S inner join Sezione SE
		on S.idSerra = SE.Serra
    where SE.MaxPiante >= 1/80 * S.MaxPiante and
		SE.MaxPiante = (
							select min(SE1.MaxPiante)
                            from Serra S1 inner join Sezione SE1
								on S1.idSerra = SE1.Serra
                            where S1.idSerra = S.idSerra and
								S1.MaxPiante >= 1/80 * SE1.MaxPiante
                                )
	group by S.idSerra;