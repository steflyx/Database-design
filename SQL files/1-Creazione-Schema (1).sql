-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='TRADITIONAL,ALLOW_INVALID_DATES';

-- -----------------------------------------------------
-- Schema progettouni
-- -----------------------------------------------------
DROP SCHEMA IF EXISTS `progettouni` ;

-- -----------------------------------------------------
-- Schema progettouni
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `progettouni` DEFAULT CHARACTER SET latin1 ;
USE `progettouni` ;

-- -----------------------------------------------------
-- Table `progettouni`.`Account`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Account` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Account` (
  `idAccount` INT(11) NOT NULL AUTO_INCREMENT,
  `Nickname` VARCHAR(45) NOT NULL,
  `Via` VARCHAR(100) NULL DEFAULT NULL,
  `NumCivico` INT(11) NULL DEFAULT NULL,
  `Citta` VARCHAR(45) NULL DEFAULT NULL,
  `Password` VARCHAR(45) NOT NULL,
  `Credibilita` INT(11) NULL DEFAULT '100',
  `Cognome` VARCHAR(45) NULL DEFAULT NULL,
  `Nome` VARCHAR(45) NULL DEFAULT NULL,
  `Email` VARCHAR(45) NOT NULL,
  `DomandaSicurezza` VARCHAR(200) NULL DEFAULT NULL,
  `RispostaSicurezza` VARCHAR(200) NULL DEFAULT NULL,
  PRIMARY KEY (`idAccount`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1
COMMENT = '     ';

CREATE UNIQUE INDEX `Email` ON `progettouni`.`Account` (`Email` ASC);

CREATE UNIQUE INDEX `Nickname` ON `progettouni`.`Account` (`Nickname` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Acqua`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Acqua` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Acqua` (
  `idAcqua` INT(11) NOT NULL AUTO_INCREMENT,
  `Quantita` VARCHAR(45) NOT NULL,
  `Periodicita` INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (`idAcqua`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Agente`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Agente` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Agente` (
  `idAgente` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Biologico` TINYINT(1) NULL DEFAULT '0',
  `Chimico` TINYINT(1) NULL DEFAULT '0',
  PRIMARY KEY (`idAgente`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Prodotto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Prodotto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Prodotto` (
  `idProdotto` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Modalita` VARCHAR(45) NULL DEFAULT NULL,
  `Attesa` INT(10) UNSIGNED NULL DEFAULT '0',
  `Tipo` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`idProdotto`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Principio`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Principio` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Principio` (
  `idPrincipio` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`idPrincipio`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Basato`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Basato` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Basato` (
  `Concentrazione` INT(10) UNSIGNED NOT NULL,
  `Prodotto` INT(11) NOT NULL,
  `Principio` INT(11) NOT NULL,
  PRIMARY KEY (`Prodotto`, `Principio`),
  CONSTRAINT `fk_Basato_Prodotto1`
    FOREIGN KEY (`Prodotto`)
    REFERENCES `progettouni`.`Prodotto` (`idProdotto`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Basato_Principio1`
    FOREIGN KEY (`Principio`)
    REFERENCES `progettouni`.`Principio` (`idPrincipio`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Basato_Principio1_idx` ON `progettouni`.`Basato` (`Principio` ASC);

CREATE INDEX `fk_Basato_Prodotto1_idx` ON `progettouni`.`Basato` (`Prodotto` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Famiglia`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Famiglia` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Famiglia` (
  `idFamiglia` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `CrescitaAerea` DOUBLE UNSIGNED NULL DEFAULT '1',
  `CrescitaRadicale` DOUBLE UNSIGNED NULL DEFAULT '1',
  PRIMARY KEY (`idFamiglia`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1
COMMENT = '     \n\n\n';


-- -----------------------------------------------------
-- Table `progettouni`.`Pianta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Pianta` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Pianta` (
  `idPianta` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Cultivar` VARCHAR(45) NULL DEFAULT NULL,
  `Dioica` TINYINT(1) NULL DEFAULT NULL,
  `DimMax` DOUBLE UNSIGNED NULL DEFAULT NULL,
  `IndiceManut` DECIMAL(5,2) UNSIGNED NULL DEFAULT '4.20',
  `CostoBase` DECIMAL(6,2) UNSIGNED NULL DEFAULT NULL,
  `Infestante` TINYINT(1) NULL DEFAULT NULL,
  `Sempreverde` TINYINT(1) NULL DEFAULT NULL,
  `Famiglia` INT(11) NULL DEFAULT NULL,
  PRIMARY KEY (`idPianta`),
  CONSTRAINT `fk_pianta_famiglia`
    FOREIGN KEY (`Famiglia`)
    REFERENCES `progettouni`.`Famiglia` (`idFamiglia`)
    ON DELETE SET NULL
    ON UPDATE CASCADE)
ENGINE = InnoDB
AUTO_INCREMENT = 601
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_pianta_famiglia_idx` ON `progettouni`.`Pianta` (`Famiglia` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PeriodoCicli`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PeriodoCicli` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PeriodoCicli` (
  `idPeriodo` INT(11) NOT NULL AUTO_INCREMENT,
  `InizioPeriodo` INT(11) NOT NULL DEFAULT '1',
  `FinePeriodo` INT(11) NOT NULL DEFAULT '12',
  `Fio_Fru` VARCHAR(45) NOT NULL,
  `Vegetativo` TINYINT(1) NOT NULL,
  PRIMARY KEY (`idPeriodo`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1
COMMENT = ' ';

CREATE UNIQUE INDEX `InizioPeriodo` ON `progettouni`.`PeriodoCicli` (`InizioPeriodo` ASC, `FinePeriodo` ASC, `Fio_Fru` ASC, `Vegetativo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`CicliPianta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`CicliPianta` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`CicliPianta` (
  `Pianta` INT(11) NOT NULL,
  `Periodo` INT(11) NOT NULL,
  PRIMARY KEY (`Pianta`, `Periodo`),
  CONSTRAINT `fk_CicliPianta_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_CicliPianta_PeriodoCicli1`
    FOREIGN KEY (`Periodo`)
    REFERENCES `progettouni`.`PeriodoCicli` (`idPeriodo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_CicliPianta_PeriodoCicli1_idx` ON `progettouni`.`CicliPianta` (`Periodo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Componente`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Componente` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Componente` (
  `idComponente` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Consistenza` VARCHAR(45) NOT NULL,
  `Permeabilita` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`idComponente`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Sede`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Sede` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Sede` (
  `idSede` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Indirizzo` VARCHAR(100) NOT NULL,
  `NumDipendenti` INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (`idSede`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE UNIQUE INDEX `Indirizzo` ON `progettouni`.`Sede` (`Indirizzo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Serra`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Serra` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Serra` (
  `idSerra` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Indirizzo` VARCHAR(100) NOT NULL,
  `Lunghezza` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Larghezza` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Altezza` INT(10) UNSIGNED NULL DEFAULT NULL,
  `NumPiante` INT(10) UNSIGNED NULL DEFAULT 0,
  `MaxPiante` INT(10) UNSIGNED NULL DEFAULT 0 ,
  `Sede` INT(11) NOT NULL,
  PRIMARY KEY (`idSerra`),
  CONSTRAINT `fk_Serra_Sede1`
    FOREIGN KEY (`Sede`)
    REFERENCES `progettouni`.`Sede` (`idSede`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Serra_Sede1_idx` ON `progettouni`.`Serra` (`Sede` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Sezione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Sezione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Sezione` (
  `idSezione` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `NumPiante` INT(10) UNSIGNED NULL DEFAULT 0,
  `MaxPiante` INT(10) UNSIGNED NULL DEFAULT 0,
  `Serra` INT(11) NOT NULL,
  PRIMARY KEY (`idSezione`),
  CONSTRAINT `fk_Sezione_Serra1`
    FOREIGN KEY (`Serra`)
    REFERENCES `progettouni`.`Serra` (`idSerra`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Sezione_Serra1_idx` ON `progettouni`.`Sezione` (`Serra` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Ripiano`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Ripiano` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Ripiano` (
  `idRipiano` INT(11) NOT NULL AUTO_INCREMENT,
  `MaxPiante` INT(11) NULL DEFAULT 0,
  `Sezione` INT(11) NOT NULL,
  PRIMARY KEY (`idRipiano`),
  CONSTRAINT `fk_Ripiano_Sezione1`
    FOREIGN KEY (`Sezione`)
    REFERENCES `progettouni`.`Sezione` (`idSezione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Ripiano_Sezione1_idx` ON `progettouni`.`Ripiano` (`Sezione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Lotto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Lotto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Lotto` (
  `idLotto` INT(11) NOT NULL AUTO_INCREMENT,
  `Fornitore` VARCHAR(45) NULL DEFAULT NULL,
  `Costo` INT(11) NULL DEFAULT NULL,
  PRIMARY KEY (`idLotto`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Esemplare`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Esemplare` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Esemplare` (
  `idEsemplare` INT(11) NOT NULL AUTO_INCREMENT,
  `Prezzo` DECIMAL(6,2) UNSIGNED NULL,
  `Dimensione` DECIMAL(6,2) UNSIGNED NULL DEFAULT NULL,
  `ManutenzioneProgrammata` TINYINT(1) NULL DEFAULT '0',
  `DataManutenzioneProgrammata` DATE NULL DEFAULT NULL,
  `Malato` TINYINT(1) NULL DEFAULT '0',
  `Venduto` TINYINT(1) NULL DEFAULT '0',
  `Pianta` INT(11) NOT NULL,
  `Lotto` INT(11) NOT NULL,
  `DataNascita` DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (`idEsemplare`),
  CONSTRAINT `fk_Esemplare_Lotto1`
    FOREIGN KEY (`Lotto`)
    REFERENCES `progettouni`.`Lotto` (`idLotto`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Esemplare_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Esemplare_Pianta1_idx` ON `progettouni`.`Esemplare` (`Pianta` ASC);

CREATE INDEX `fk_Esemplare_Lotto1_idx` ON `progettouni`.`Esemplare` (`Lotto` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Terreno`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Terreno` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Terreno` (
  `idTerreno` INT(11) NOT NULL AUTO_INCREMENT,
  `Consistenza` VARCHAR(45) NULL DEFAULT NULL,
  `Permeabilita` VARCHAR(45) NULL DEFAULT NULL,
  `pH` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`idTerreno`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Contenitore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Contenitore` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Contenitore` (
  `idContenitore` INT(11) NOT NULL AUTO_INCREMENT,
  `Irrigazione` VARCHAR(45) NULL DEFAULT NULL,
  `Superficie` INT(10) UNSIGNED NOT NULL,
  `Ripiano` INT(11) NULL DEFAULT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Terreno` INT(11) NULL,
  PRIMARY KEY (`idContenitore`),
  CONSTRAINT `fk_Contenitore_Ripiano1`
    FOREIGN KEY (`Ripiano`)
    REFERENCES `progettouni`.`Ripiano` (`idRipiano`)
    ON DELETE SET NULL
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Contenitore_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Contenitore_Terreno1`
    FOREIGN KEY (`Terreno`)
    REFERENCES `progettouni`.`Terreno` (`idTerreno`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Contenitore_Ripiano1_idx` ON `progettouni`.`Contenitore` (`Ripiano` ASC);

CREATE INDEX `fk_Contenitore_Esemplare1_idx` ON `progettouni`.`Contenitore` (`Esemplare` ASC);

CREATE INDEX `fk_Contenitore_Terreno1_idx` ON `progettouni`.`Contenitore` (`Terreno` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`ComposizioneContenitore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ComposizioneContenitore` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ComposizioneContenitore` (
  `Percentuale` INT(11) NULL DEFAULT NULL,
  `Contenitore` INT(11) NOT NULL,
  `Componente` INT(11) NOT NULL,
  PRIMARY KEY (`Contenitore`, `Componente`),
  CONSTRAINT `fk_ComposizioneContenitore_Contenitore1`
    FOREIGN KEY (`Contenitore`)
    REFERENCES `progettouni`.`Contenitore` (`idContenitore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ComposizioneContenitore_Componente1`
    FOREIGN KEY (`Componente`)
    REFERENCES `progettouni`.`Componente` (`idComponente`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ComposizioneContenitore_Componente1_idx` ON `progettouni`.`ComposizioneContenitore` (`Componente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Luce`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Luce` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Luce` (
  `idLuce` INT(11) NOT NULL AUTO_INCREMENT,
  `Diretta` TINYINT(1) NULL DEFAULT NULL,
  `NumOre` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Quantita` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`idLuce`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Giardino`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Giardino` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Giardino` (
  `Numero` INT(11) NOT NULL AUTO_INCREMENT,
  `Clima` VARCHAR(45) NULL DEFAULT NULL,
  `IndiceManut` VARCHAR(45) NULL DEFAULT NULL,
  `Account` INT(11) NOT NULL,
  PRIMARY KEY (`Numero`, `Account`),
  CONSTRAINT `fk_Giardino_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Giardino_Account1_idx` ON `progettouni`.`Giardino` (`Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Settore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Settore` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Settore` (
  `idSettore` INT(11) NOT NULL AUTO_INCREMENT,
  `DirCardinale` VARCHAR(45) NULL DEFAULT NULL,
  `Base` VARCHAR(45) NULL DEFAULT NULL,
  `Terreno` INT(11) NULL DEFAULT NULL,
  `LuceAttuale` INT(11) NULL DEFAULT NULL,
  `LuceIniziale` INT(11) NULL DEFAULT NULL,
  `NumeroGiardino` INT(11) NOT NULL,
  `Account` INT(11) NOT NULL,
  `Area` INT(11) NULL DEFAULT NULL, 
  PRIMARY KEY (`idSettore`),
  CONSTRAINT `fk_Settore_Terreno1`
    FOREIGN KEY (`Terreno`)
    REFERENCES `progettouni`.`Terreno` (`idTerreno`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Settore_Luce1`
    FOREIGN KEY (`LuceAttuale`)
    REFERENCES `progettouni`.`Luce` (`idLuce`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Settore_Luce2`
    FOREIGN KEY (`LuceIniziale`)
    REFERENCES `progettouni`.`Luce` (`idLuce`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Settore_Giardino1`
    FOREIGN KEY (`NumeroGiardino` , `Account`)
    REFERENCES `progettouni`.`Giardino` (`Numero` , `Account`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Settore_Terreno1_idx` ON `progettouni`.`Settore` (`Terreno` ASC);

CREATE INDEX `fk_Settore_Luce1_idx` ON `progettouni`.`Settore` (`LuceAttuale` ASC);

CREATE INDEX `fk_Settore_Luce2_idx` ON `progettouni`.`Settore` (`LuceIniziale` ASC);

CREATE INDEX `fk_Settore_Giardino1_idx` ON `progettouni`.`Settore` (`NumeroGiardino` ASC, `Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`ComposizioneSettore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ComposizioneSettore` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ComposizioneSettore` (
  `Percentuale` INT(11) NOT NULL,
  `Settore` INT(11) NOT NULL,
  `Componente` INT(11) NOT NULL,
  PRIMARY KEY (`Settore`, `Componente`),
  CONSTRAINT `fk_ComposizioneSettore_Settore1`
    FOREIGN KEY (`Settore`)
    REFERENCES `progettouni`.`Settore` (`idSettore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ComposizioneSettore_Componente1`
    FOREIGN KEY (`Componente`)
    REFERENCES `progettouni`.`Componente` (`idComponente`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ComposizioneSettore_Componente1_idx` ON `progettouni`.`ComposizioneSettore` (`Componente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Elemento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Elemento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Elemento` (
  `idElemento` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  `Simbolo` VARCHAR(45) NULL DEFAULT NULL,
  `Dimensione` VARCHAR(45) NULL DEFAULT NULL,
  PRIMARY KEY (`idElemento`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`ComposizioneTerreno`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ComposizioneTerreno` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ComposizioneTerreno` (
  `Concentrazione` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Terreno` INT(11) NOT NULL,
  `Elemento` INT(11) NOT NULL,
  PRIMARY KEY (`Terreno`, `Elemento`),
  CONSTRAINT `fk_ComposizioneTerreno_Terreno1`
    FOREIGN KEY (`Terreno`)
    REFERENCES `progettouni`.`Terreno` (`idTerreno`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ComposizioneTerreno_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ComposizioneTerreno_Elemento1_idx` ON `progettouni`.`ComposizioneTerreno` (`Elemento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`TipoConcimazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`TipoConcimazione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`TipoConcimazione` (
  `idConcimazione` INT(11) NOT NULL AUTO_INCREMENT,
  `InizioPeriodo` INT(10) UNSIGNED NULL DEFAULT '1',
  `FinePeriodo` INT(10) UNSIGNED NULL DEFAULT '12',
  `Periodicita` INT(10) UNSIGNED NULL DEFAULT '0',
  PRIMARY KEY (`idConcimazione`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Concimazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Concimazione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Concimazione` (
  `NumeroConcimazione` INT(10) UNSIGNED NOT NULL DEFAULT '0',
  `TipoConcimazione` INT(11) NOT NULL,
  PRIMARY KEY (`NumeroConcimazione`, `TipoConcimazione`),
  CONSTRAINT `fk_Concimazione_TipoConcimazione1`
    FOREIGN KEY (`TipoConcimazione`)
    REFERENCES `progettouni`.`TipoConcimazione` (`idConcimazione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Concimazione_TipoConcimazione1_idx` ON `progettouni`.`Concimazione` (`TipoConcimazione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`CondizioniFavorevoli`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`CondizioniFavorevoli` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`CondizioniFavorevoli` (
  `idCondizioniFavorevorevoli` INT(11) NOT NULL AUTO_INCREMENT,
  `Idratazione` VARCHAR(45) NULL DEFAULT NULL,
  `pH` VARCHAR(45) NULL DEFAULT NULL,
  `Umidita` VARCHAR(45) NULL DEFAULT NULL,
  `Temperatura` VARCHAR(45) NULL DEFAULT NULL,
  `Illuminazione` VARCHAR(45) NULL DEFAULT NULL,
  `Mese` INT(11) NULL DEFAULT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`idCondizioniFavorevorevoli`, `Agente`),
  CONSTRAINT `fk_CondizioniFavorevoli_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_CondizioniFavorevoli_Agente1_idx` ON `progettouni`.`CondizioniFavorevoli` (`Agente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Contrasto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Contrasto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Contrasto` (
  `DosaggioConsigliato` INT(10) UNSIGNED NOT NULL,
  `Prodotto` INT(11) NOT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`Prodotto`, `Agente`),
  CONSTRAINT `fk_Contrasto_Prodotto1`
    FOREIGN KEY (`Prodotto`)
    REFERENCES `progettouni`.`Prodotto` (`idProdotto`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Contrasto_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Contrasto_Prodotto1_idx` ON `progettouni`.`Contrasto` (`Prodotto` ASC);

CREATE INDEX `fk_Contrasto_Agente1_idx` ON `progettouni`.`Contrasto` (`Agente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`MisurazioneAmbientale`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`MisurazioneAmbientale` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`MisurazioneAmbientale` (
  `TimeStamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Umidita` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Temperatura` INT(11) NULL DEFAULT NULL,
  `Illuminazione` VARCHAR(45) NULL DEFAULT NULL,
  `Sezione` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStamp`, `Sezione`),
  CONSTRAINT `fk_MisurazioneAmbientale_Sezione1`
    FOREIGN KEY (`Sezione`)
    REFERENCES `progettouni`.`Sezione` (`idSezione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_MisurazioneAmbientale_Sezione1_idx` ON `progettouni`.`MisurazioneAmbientale` (`Sezione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`ReportDiagnostica`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ReportDiagnostica` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ReportDiagnostica` (
  `Data` DATE NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `TimeStampMisurazione` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Sezione` INT(11) NOT NULL,
  PRIMARY KEY (`Data`, `Esemplare`),
  CONSTRAINT `fk_ReportDiagnostica_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ReportDiagnostica_TimeStampMisurazione1`
    FOREIGN KEY (`TimeStampMisurazione`)
    REFERENCES `progettouni`.`MisurazioneAmbientale` (`TimeStamp`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_ReportDiagnostica_Sezione1`
    FOREIGN KEY (`Sezione`)
    REFERENCES `progettouni`.`Sezione` (`idSezione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ReportDiagnostica_Esemplare1_idx` ON `progettouni`.`ReportDiagnostica` (`Esemplare` ASC);

CREATE INDEX `fk_ReportDiagnostica_Sezione1_idx` ON `progettouni`.`ReportDiagnostica` (`Sezione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Intervento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Intervento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Intervento` (
  `idIntervento` INT(11) NOT NULL AUTO_INCREMENT,
  `Effettuato` TINYINT(1) NULL DEFAULT '0',
  `Data` DATE NULL DEFAULT NULL,
  `Costo` DECIMAL(6,2) NULL DEFAULT NULL,
  `Entita` INT(11) NULL DEFAULT '1',
  `Motivo` VARCHAR(45) NULL DEFAULT NULL,
  `Tipo` VARCHAR(45) NULL DEFAULT NULL,
  `Esemplare` INT(11) NOT NULL,
  PRIMARY KEY (`idIntervento`),
  CONSTRAINT `fk_Intervento_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Intervento_Esemplare1_idx` ON `progettouni`.`Intervento` (`Esemplare` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Decisione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Decisione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Decisione` (
  `Esperto` VARCHAR(45) NULL DEFAULT NULL,
  `DataReport` DATE NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Intervento` INT(11) NOT NULL,
  PRIMARY KEY (`DataReport`, `Esemplare`, `Intervento`),
  CONSTRAINT `fk_Decisione_ReportDiagnostica1`
    FOREIGN KEY (`DataReport` , `Esemplare`)
    REFERENCES `progettouni`.`ReportDiagnostica` (`Data` , `Esemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Decisione_Intervento1`
    FOREIGN KEY (`Intervento`)
    REFERENCES `progettouni`.`Intervento` (`idIntervento`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Decisione_ReportDiagnostica1_idx` ON `progettouni`.`Decisione` (`DataReport` ASC, `Esemplare` ASC);

CREATE INDEX `fk_Decisione_Intervento1_idx` ON `progettouni`.`Decisione` (`Intervento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`DiagnosiEsperto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`DiagnosiEsperto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`DiagnosiEsperto` (
  `Esperto` VARCHAR(45) NULL DEFAULT NULL,
  `Numero` INT(11) NOT NULL,
  `DataReport` DATE NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`DataReport`, `Esemplare`, `Agente`,`Numero`),
  CONSTRAINT `fk_DiagnosiEsperto_ReportDiagnostica1`
    FOREIGN KEY (`DataReport` , `Esemplare`)
    REFERENCES `progettouni`.`ReportDiagnostica` (`Data` , `Esemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_DiagnosiEsperto_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_DiagnosiEsperto_Agente1_idx` ON `progettouni`.`DiagnosiEsperto` (`Agente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`DiagnosiPossibili`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`DiagnosiPossibili` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`DiagnosiPossibili` (
  `Attinenza` INT(10) UNSIGNED NULL DEFAULT NULL,
  `DataReport` DATE NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`DataReport`, `Esemplare`, `Agente`),
  CONSTRAINT `fk_DiagnosiPossibili_ReportDiagnostica1`
    FOREIGN KEY (`DataReport` , `Esemplare`)
    REFERENCES `progettouni`.`ReportDiagnostica` (`Data` , `Esemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_DiagnosiPossibili_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_DiagnosiPossibili_Agente1_idx` ON `progettouni`.`DiagnosiPossibili` (`Agente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`ElementiCoinvolti`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ElementiCoinvolti` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ElementiCoinvolti` (
  `Elemento` INT(11) NOT NULL,
  `CondizioniFavorevorevoli` INT(11) NOT NULL,
  PRIMARY KEY (`Elemento`, `CondizioniFavorevorevoli`),
  CONSTRAINT `fk_ElementiCoinvolti_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE,
  CONSTRAINT `fk_ElementiCoinvolti_CondizioniFavorevoli1`
    FOREIGN KEY (`CondizioniFavorevorevoli`)
    REFERENCES `progettouni`.`CondizioniFavorevoli` (`idCondizioniFavorevorevoli`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ElementiCoinvolti_CondizioniFavorevoli1_idx` ON `progettouni`.`ElementiCoinvolti` (`CondizioniFavorevorevoli` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Temperatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Temperatura` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Temperatura` (
  `idTemp` INT(11) NOT NULL AUTO_INCREMENT,
  `TempMin` INT(11) NOT NULL,
  `TempMax` INT(11) NOT NULL,
  PRIMARY KEY (`idTemp`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Esigenze`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Esigenze` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Esigenze` (
  `Pianta` INT(11) NOT NULL,
  `AcquaVegetativo` INT(11) NULL DEFAULT NULL,
  `AcquaRiposo` INT(11) NULL DEFAULT NULL,
  `Temperatura` INT(11) NULL DEFAULT NULL,
  `LuceVegetativo` INT(11) NULL DEFAULT NULL,
  `LuceRiposo` INT(11) NULL DEFAULT NULL,
  `Terreno` INT(11) NULL DEFAULT NULL,
  PRIMARY KEY (`Pianta`),
  CONSTRAINT `fk_Esigenze_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Esigenze_Acqua1`
    FOREIGN KEY (`AcquaVegetativo`)
    REFERENCES `progettouni`.`Acqua` (`idAcqua`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Esigenze_Acqua2`
    FOREIGN KEY (`AcquaRiposo`)
    REFERENCES `progettouni`.`Acqua` (`idAcqua`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Esigenze_Temperatura1`
    FOREIGN KEY (`Temperatura`)
    REFERENCES `progettouni`.`Temperatura` (`idTemp`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Esigenze_Luce1`
    FOREIGN KEY (`LuceVegetativo`)
    REFERENCES `progettouni`.`Luce` (`idLuce`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Esigenze_Luce2`
    FOREIGN KEY (`LuceRiposo`)
    REFERENCES `progettouni`.`Luce` (`idLuce`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Esigenze_Terreno1`
    FOREIGN KEY (`Terreno`)
    REFERENCES `progettouni`.`Terreno` (`idTerreno`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Esigenze_Acqua1_idx` ON `progettouni`.`Esigenze` (`AcquaVegetativo` ASC);

CREATE INDEX `fk_Esigenze_Acqua2_idx` ON `progettouni`.`Esigenze` (`AcquaRiposo` ASC);

CREATE INDEX `fk_Esigenze_Temperatura1_idx` ON `progettouni`.`Esigenze` (`Temperatura` ASC);

CREATE INDEX `fk_Esigenze_Luce1_idx` ON `progettouni`.`Esigenze` (`LuceVegetativo` ASC);

CREATE INDEX `fk_Esigenze_Luce2_idx` ON `progettouni`.`Esigenze` (`LuceRiposo` ASC);

CREATE INDEX `fk_Esigenze_Terreno1_idx` ON `progettouni`.`Esigenze` (`Terreno` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`EsigenzeConcimazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`EsigenzeConcimazione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`EsigenzeConcimazione` (
  `Pianta` INT(11) NOT NULL,
  `TipoConcimazione` INT(11) NOT NULL,
  PRIMARY KEY (`Pianta`, `TipoConcimazione`),
  CONSTRAINT `fk_EsigenzeConcimazione_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_EsigenzeConcimazione_TipoConcimazione1`
    FOREIGN KEY (`TipoConcimazione`)
    REFERENCES `progettouni`.`TipoConcimazione` (`idConcimazione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_EsigenzeConcimazione_TipoConcimazione1_idx` ON `progettouni`.`EsigenzeConcimazione` (`TipoConcimazione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`EsigenzeElemento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`EsigenzeElemento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`EsigenzeElemento` (
  `Concentrazione` INT(11) NULL DEFAULT NULL,
  `Elemento` INT(11) NOT NULL,
  `Pianta` INT(11) NOT NULL,
  PRIMARY KEY (`Elemento`, `Pianta`),
  CONSTRAINT `fk_EsigenzeElemento_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_EsigenzeElemento_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_EsigenzeElemento_Pianta1_idx` ON `progettouni`.`EsigenzeElemento` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Punto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Punto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Punto` (
  `X` INT(10) UNSIGNED NOT NULL,
  `Y` INT(10) UNSIGNED NOT NULL,
  `OrdPosizione` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Settore` INT(11) NOT NULL,
  PRIMARY KEY (`X`, `Y`, `Settore`),
  CONSTRAINT `fk_Punto_Settore1`
    FOREIGN KEY (`Settore`)
    REFERENCES `progettouni`.`Settore` (`idSettore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Punto_Settore1_idx` ON `progettouni`.`Punto` (`Settore` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`FormaPianta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`FormaPianta` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`FormaPianta` (
  `Pianta` INT(11) NOT NULL,
  `X` INT(10) UNSIGNED NOT NULL,
  `Y` INT(10) UNSIGNED NOT NULL,
  `Settore` INT(11) NOT NULL,
  `Dim` INT(10) UNSIGNED NOT NULL,
  `PosPianta` INT(10) UNSIGNED NOT NULL,
  PRIMARY KEY (`Pianta`, `X`, `Y`, `Settore`),
  CONSTRAINT `fk_FormaPianta_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_FormaPianta_Punto1`
    FOREIGN KEY (`X` , `Y` , `Settore`)
    REFERENCES `progettouni`.`Punto` (`X` , `Y` , `Settore`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_FormaPianta_Punto1_idx` ON `progettouni`.`FormaPianta` (`X` ASC, `Y` ASC, `Settore` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Sintomo`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Sintomo` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Sintomo` (
  `idSintomo` INT(11) NOT NULL AUTO_INCREMENT,
  `Descrizione` VARCHAR(500) NOT NULL,
  PRIMARY KEY (`idSintomo`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`Immagine`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Immagine` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Immagine` (
  `idImmagine` INT(11) NOT NULL AUTO_INCREMENT,
  `NomeFile` VARCHAR(100) NOT NULL,
  `Sintomo` INT(11) NOT NULL,
  PRIMARY KEY (`idImmagine`, `Sintomo`),
  CONSTRAINT `fk_Immagine_Sintomo1`
    FOREIGN KEY (`Sintomo`)
    REFERENCES `progettouni`.`Sintomo` (`idSintomo`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Immagine_Sintomo1_idx` ON `progettouni`.`Immagine` (`Sintomo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`InfoSintomi`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`InfoSintomi` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`InfoSintomi` (
  `DataReport` DATE NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Sintomo` INT(11) NOT NULL,
  PRIMARY KEY (`DataReport`, `Esemplare`, `Sintomo`),
  CONSTRAINT `fk_InfoSintomi_ReportDiagnostica1`
    FOREIGN KEY (`DataReport` , `Esemplare`)
    REFERENCES `progettouni`.`ReportDiagnostica` (`Data` , `Esemplare`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_InfoSintomi_Sintomo1`
    FOREIGN KEY (`Sintomo`)
    REFERENCES `progettouni`.`Sintomo` (`idSintomo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_InfoSintomi_Sintomo1_idx` ON `progettouni`.`InfoSintomi` (`Sintomo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Isolamento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Isolamento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Isolamento` (
  `Esemplare` INT(11) NOT NULL,
  `Sezione` INT(11) NOT NULL,
  PRIMARY KEY (`Esemplare`, `Sezione`),
  CONSTRAINT `fk_Isolamento_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Isolamento_Sezione1`
    FOREIGN KEY (`Sezione`)
    REFERENCES `progettouni`.`Sezione` (`idSezione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Isolamento_Sezione1_idx` ON `progettouni`.`Isolamento` (`Sezione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`MisurazioneContenitore`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`MisurazioneContenitore` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`MisurazioneContenitore` (
  `TimeStamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `pH` VARCHAR(45) NULL DEFAULT NULL,
  `Idratazione` VARCHAR(45) NULL DEFAULT NULL,
  `Contenitore` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStamp`, `Contenitore`),
  CONSTRAINT `fk_MisurazioneContenitore_Contenitore1`
    FOREIGN KEY (`Contenitore`)
    REFERENCES `progettouni`.`Contenitore` (`idContenitore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_MisurazioneContenitore_Contenitore1_idx` ON `progettouni`.`MisurazioneContenitore` (`Contenitore` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`TipoPotatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`TipoPotatura` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`TipoPotatura` (
  `idTipoPotatura` INT(11) NOT NULL AUTO_INCREMENT,
  `Nome` VARCHAR(45) NOT NULL,
  PRIMARY KEY (`idTipoPotatura`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;


-- -----------------------------------------------------
-- Table `progettouni`.`NecessitaPotatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`NecessitaPotatura` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`NecessitaPotatura` (
  `Quantita` INT(10) UNSIGNED NULL DEFAULT NULL,
  `TipoPotatura` INT(11) NOT NULL,
  `Pianta` INT(11) NOT NULL,
  PRIMARY KEY (`TipoPotatura`, `Pianta`),
  CONSTRAINT `fk_NecessitaPotatura_TipoPotatura1`
    FOREIGN KEY (`TipoPotatura`)
    REFERENCES `progettouni`.`TipoPotatura` (`idTipoPotatura`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_NecessitaPotatura_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_NecessitaPotatura_Pianta1_idx` ON `progettouni`.`NecessitaPotatura` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Ordine`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Ordine` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Ordine` (
  `idOrdine` INT(11) NOT NULL AUTO_INCREMENT,
  `Stato` VARCHAR(45) NOT NULL DEFAULT 'InProcessazione',
  `TimeStamp` TIMESTAMP NOT NULL,
  `Account` INT(11) NOT NULL,
  PRIMARY KEY (`idOrdine`),
  CONSTRAINT `fk_Ordine_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Ordine_Account1_idx` ON `progettouni`.`Ordine` (`Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Pendente`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Pendente` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Pendente` (
  `Ordine` INT(11) NOT NULL,
  `Pianta` INT(11) NOT NULL,
  `Quantita` INT(10) UNSIGNED NOT NULL DEFAULT '1',
  PRIMARY KEY (`Ordine`, `Pianta`),
  CONSTRAINT `fk_Ordine_has_Pianta_Ordine1`
    FOREIGN KEY (`Ordine`)
    REFERENCES `progettouni`.`Ordine` (`idOrdine`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Ordine_has_Pianta_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Ordine_has_Pianta_Pianta1_idx` ON `progettouni`.`Pendente` (`Pianta` ASC);

CREATE INDEX `fk_Ordine_has_Pianta_Ordine1_idx` ON `progettouni`.`Pendente` (`Ordine` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PeriodoAttacchi`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PeriodoAttacchi` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PeriodoAttacchi` (
  `InizioPeriodo` INT(10) UNSIGNED NOT NULL,
  `FinePeriodo` INT(10) UNSIGNED NOT NULL,
  `Entita` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Probabilita` INT(10) UNSIGNED NOT NULL,
  `Pianta` INT(11) NOT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`InizioPeriodo`, `FinePeriodo`, `Pianta`, `Agente`),
  CONSTRAINT `fk_PeriodoAttacchi_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_PeriodoAttacchi_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PeriodoAttacchi_Agente1_idx` ON `progettouni`.`PeriodoAttacchi` (`Agente` ASC);

CREATE INDEX `fk_PeriodoAttacchi_Pianta1_idx` ON `progettouni`.`PeriodoAttacchi` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PeriodoNonUtilizzo`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PeriodoNonUtilizzo` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PeriodoNonUtilizzo` (
  `InizioPeriodo` INT(11) NOT NULL,
  `FinePeriodo` INT(11) NOT NULL,
  `Prodotto` INT(11) NOT NULL,
  PRIMARY KEY (`InizioPeriodo`, `Prodotto`),
  CONSTRAINT `fk_PeriodoNonUtilizzo_Prodotto1`
    FOREIGN KEY (`Prodotto`)
    REFERENCES `progettouni`.`Prodotto` (`idProdotto`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PeriodoNonUtilizzo_Prodotto1_idx` ON `progettouni`.`PeriodoNonUtilizzo` (`Prodotto` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PeriodoPotatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PeriodoPotatura` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PeriodoPotatura` (
  `InizioPeriodo` INT(10) UNSIGNED NOT NULL DEFAULT '1',
  `FinePeriodo` INT(10) UNSIGNED NOT NULL DEFAULT '12',
  `Pianta` INT(11) NOT NULL,
  `TipoPotatura` INT(11) NOT NULL,
  PRIMARY KEY (`InizioPeriodo`, `FinePeriodo`, `Pianta`, `TipoPotatura`),
  CONSTRAINT `fk_PeriodoPotatura_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_PeriodoPotatura_TipoPotatura1`
    FOREIGN KEY (`TipoPotatura`)
    REFERENCES `progettouni`.`TipoPotatura` (`idTipoPotatura`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PeriodoPotatura_Pianta1_idx` ON `progettouni`.`PeriodoPotatura` (`Pianta` ASC);

CREATE INDEX `fk_PeriodoPotatura_TipoPotatura1_idx` ON `progettouni`.`PeriodoPotatura` (`TipoPotatura` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PeriodoRinvasi`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PeriodoRinvasi` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PeriodoRinvasi` (
  `InizioPeriodo` INT(10) UNSIGNED NOT NULL,
  `FinePeriodo` INT(10) UNSIGNED NOT NULL,
  `Pianta` INT(11) NOT NULL,
  PRIMARY KEY (`InizioPeriodo`, `FinePeriodo`, `Pianta`),
  CONSTRAINT `fk_PeriodoRinvasi_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PeriodoRinvasi_Pianta1_idx` ON `progettouni`.`PeriodoRinvasi` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Post`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Post` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Post` (
  `TimeStamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Testo` TEXT NOT NULL,
  `Thread` TEXT NULL DEFAULT NULL,
  `Account` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStamp`, `Account`),
  CONSTRAINT `fk_Post_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Post_Account1_idx` ON `progettouni`.`Post` (`Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Preferenze`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Preferenze` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Preferenze` (
  `idPreferenze` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `Dimensione` VARCHAR(45) NULL DEFAULT NULL,
  `ImpDimensione` INT(11) NULL DEFAULT NULL,
  `Dioica` TINYINT(1) NULL DEFAULT NULL,
  `ImpDioica` INT(11) NULL DEFAULT NULL,
  `Infestante` TINYINT(1) NULL DEFAULT NULL,
  `ImpInfestante` INT(11) NULL DEFAULT NULL,
  `Temp` VARCHAR(45) NULL DEFAULT NULL,
  `ImpTemp` INT(11) NULL DEFAULT NULL,
  `Sempreverde` TINYINT(1) NULL DEFAULT NULL,
  `ImpSempreverde` INT(11) NULL DEFAULT NULL,
  `Costo` VARCHAR(45) NULL DEFAULT NULL,
  `ImpCosto` INT(11) NULL DEFAULT NULL,
  `Luce` VARCHAR(45) NULL DEFAULT NULL,
  `ImpLuce` INT(11) NULL DEFAULT NULL,
  `Acqua` VARCHAR(45) NULL DEFAULT NULL,
  `ImpAcqua` INT(11) NULL DEFAULT NULL,
  `Terreno` INT(11) NULL DEFAULT NULL,
  `ImpTerreno` INT(11) NULL DEFAULT NULL,
  `IndiceManut` VARCHAR(45) NULL DEFAULT NULL,
  `ImpIndiceManut` INT(11) NULL DEFAULT NULL,
  `Account` INT(11) NOT NULL,
  PRIMARY KEY (`idPreferenze`),
  CONSTRAINT `fk_Preferenze_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Preferenze_Terreno1`
    FOREIGN KEY (`Terreno`)
    REFERENCES `progettouni`.`Terreno` (`idTerreno`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Preferenze_Terreno1_idx` ON `progettouni`.`Preferenze` (`Terreno` ASC);

CREATE INDEX `fk_Preferenze_Account1_idx` ON `progettouni`.`Preferenze` (`Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PreferenzePeriodi`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PreferenzePeriodi` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PreferenzePeriodi` (
  `Importanza` INT(11) NOT NULL,
  `Preferenze` INT(10) UNSIGNED NOT NULL,
  `Periodo` INT(11) NOT NULL,
  PRIMARY KEY (`Importanza`, `Preferenze`, `Periodo`),
  CONSTRAINT `fk_PreferenzePeriodi_Preferenze1`
    FOREIGN KEY (`Preferenze`)
    REFERENCES `progettouni`.`Preferenze` (`idPreferenze`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PreferenzePeriodi_PeriodoCicli1`
    FOREIGN KEY (`Periodo`)
    REFERENCES `progettouni`.`PeriodoCicli` (`idPeriodo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PreferenzePeriodi_Preferenze1_idx` ON `progettouni`.`PreferenzePeriodi` (`Preferenze` ASC);

CREATE INDEX `fk_PreferenzePeriodi_PeriodoCicli1_idx` ON `progettouni`.`PreferenzePeriodi` (`Periodo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PresenzaElemento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`PresenzaElemento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`PresenzaElemento` (
  `Quantita` INT(11) NULL DEFAULT NULL,
  `Contenitore` INT(11) NOT NULL,
  `TimeStampMisurazione` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Elemento` INT(11) NOT NULL,
  PRIMARY KEY (`Contenitore`, `TimeStampMisurazione`, `Elemento`),
  CONSTRAINT `fk_PresenzaElemento_Contenitore1`
    FOREIGN KEY (`Contenitore`)
    REFERENCES `progettouni`.`Contenitore` (`idContenitore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PresenzaElemento_MisurazioneContenitore1`
    FOREIGN KEY (`TimeStampMisurazione`)
    REFERENCES `progettouni`.`MisurazioneContenitore` (`TimeStamp`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PresenzaElemento_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_PresenzaElemento_MisurazioneContenitore1_idx` ON `progettouni`.`PresenzaElemento` (`TimeStampMisurazione` ASC);

CREATE INDEX `fk_PresenzaElemento_Elemento1_idx` ON `progettouni`.`PresenzaElemento` (`Elemento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Quantita`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`QuantitaElementoPerConcimazione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`QuantitaElementoPerConcimazione` (
  `Quantita` INT(10) UNSIGNED NOT NULL,
  `NumeroConcimazione` INT(10) UNSIGNED NOT NULL,
  `Concimazione` INT(11) NOT NULL,
  `Elemento` INT(11) NOT NULL,
  PRIMARY KEY (`NumeroConcimazione`, `Concimazione`, `Elemento`),
  CONSTRAINT `fk_Quantita_Concimazione1`
    FOREIGN KEY (`NumeroConcimazione` , `Concimazione`)
    REFERENCES `progettouni`.`Concimazione` (`NumeroConcimazione` , `TipoConcimazione`)
    ON DELETE NO ACTION
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Quantita_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Quantita_Concimazione1_idx` ON `progettouni`.`QuantitaElementoPerConcimazione` (`NumeroConcimazione` ASC, `Concimazione` ASC);

CREATE INDEX `fk_Quantita_Elemento1_idx` ON `progettouni`.`QuantitaElementoPerConcimazione` (`Elemento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Relativo`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Relativo` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Relativo` (
  `Ordine` INT(11) NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  PRIMARY KEY (`Ordine`, `Esemplare`),
  CONSTRAINT `fk_Ordine_has_Esemplare_Ordine1`
    FOREIGN KEY (`Ordine`)
    REFERENCES `progettouni`.`Ordine` (`idOrdine`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Ordine_has_Esemplare_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Ordine_has_Esemplare_Esemplare1_idx` ON `progettouni`.`Relativo` (`Esemplare` ASC);

CREATE INDEX `fk_Ordine_has_Esemplare_Ordine1_idx` ON `progettouni`.`Relativo` (`Ordine` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`ReportConsigliAcquisto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`ReportConsigliAcquisto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`ReportConsigliAcquisto` (
  `Data` DATE NOT NULL,
  `Note` VARCHAR(45) NULL DEFAULT NULL,
  `Quantita` INT(10) UNSIGNED NULL DEFAULT NULL,
  `Pianta` INT(11) NOT NULL,
  PRIMARY KEY (`Data`, `Pianta`),
  CONSTRAINT `fk_ReportConsigliAcquisto_pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_ReportConsigliAcquisto_pianta1_idx` ON `progettouni`.`ReportConsigliAcquisto` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Risposta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Risposta` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Risposta` (
  `TimeStamp` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Testo` TEXT NOT NULL,
  `Account` INT(11) NOT NULL,
  `TimeStampPost` TIMESTAMP NULL DEFAULT NULL,
  `AccountPost` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStamp`, `Account`),
  CONSTRAINT `fk_Risposta_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Risposta_Post1`
    FOREIGN KEY (`TimeStampPost` , `AccountPost`)
    REFERENCES `progettouni`.`Post` (`TimeStamp` , `Account`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Risposta_Account1_idx` ON `progettouni`.`Risposta` (`Account` ASC);

CREATE INDEX `fk_Risposta_Post1_idx` ON `progettouni`.`Risposta` (`TimeStampPost` ASC, `AccountPost` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Scheda`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Scheda` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Scheda` (
  `idScheda` INT(11) NOT NULL AUTO_INCREMENT,
  `DataAcquisto` TIMESTAMP NOT NULL,
  `Collocazione` VARCHAR(45) NULL DEFAULT NULL,
  `DimVaso` DECIMAL(6,2) UNSIGNED DEFAULT NULL,
  `DimAcquisto` DECIMAL(6,2) UNSIGNED NOT NULL,
  `ManutenzioneAutomatica` TINYINT(1) NULL DEFAULT '0',
  `DataManutenzioneAutomatica` DATE NULL DEFAULT NULL,
  `NomePianta` VARCHAR(45) NOT NULL,
  `Esemplare` INT(11) NOT NULL,
  `Account` INT(11) NOT NULL,
  PRIMARY KEY (`idScheda`),
  CONSTRAINT `fk_Scheda_Esemplare1`
    FOREIGN KEY (`Esemplare`)
    REFERENCES `progettouni`.`Esemplare` (`idEsemplare`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Scheda_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Scheda_Pianta1_idx` ON `progettouni`.`Scheda` (`NomePianta` ASC);

CREATE INDEX `fk_Scheda_Esemplare1_idx` ON `progettouni`.`Scheda` (`Esemplare` ASC);

CREATE INDEX `fk_Scheda_Account1_idx` ON `progettouni`.`Scheda` (`Account` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`TipoInterventoConcimazione`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`TipoInterventoConcimazione` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`TipoInterventoConcimazione` (
  `Intervento` INT(11) NOT NULL,
  `NumeroConcimazione` INT(10) UNSIGNED NOT NULL,
  `TipoConcimazione` INT(11) NOT NULL,
  PRIMARY KEY (`Intervento`, `NumeroConcimazione`, `TipoConcimazione`),
  CONSTRAINT `fk_TipoInterventoConcimazione_Intervento1`
    FOREIGN KEY (`Intervento`)
    REFERENCES `progettouni`.`Intervento` (`idIntervento`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_TipoInterventoConcimazione_Concimazione1`
    FOREIGN KEY (`NumeroConcimazione` , `TipoConcimazione`)
    REFERENCES `progettouni`.`Concimazione` (`NumeroConcimazione` , `TipoConcimazione`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_TipoInterventoConcimazione_Concimazione1_idx` ON `progettouni`.`TipoInterventoConcimazione` (`NumeroConcimazione` ASC, `TipoConcimazione` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`TipoInterventoPotatura`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`TipoInterventoPotatura` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`TipoInterventoPotatura` (
  `Intervento` INT(11) NOT NULL,
  `TipoPotatura` INT(11) NOT NULL,
  PRIMARY KEY (`Intervento`, `TipoPotatura`),
  CONSTRAINT `fk_TipoInterventoPotatura_Intervento1`
    FOREIGN KEY (`Intervento`)
    REFERENCES `progettouni`.`Intervento` (`idIntervento`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_TipoInterventoPotatura_TipoPotatura1`
    FOREIGN KEY (`TipoPotatura`)
    REFERENCES `progettouni`.`TipoPotatura` (`idTipoPotatura`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_TipoInterventoPotatura_TipoPotatura1_idx` ON `progettouni`.`TipoInterventoPotatura` (`TipoPotatura` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Trattamento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Trattamento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Trattamento` (
  `Prevenzione` TINYINT(1) NULL DEFAULT '0',
  `Intervento` INT(11) NOT NULL,
  `Agente` INT(11) NOT NULL,
  PRIMARY KEY (`Intervento`, `Agente`),
  CONSTRAINT `fk_Trattamento_Intervento1`
    FOREIGN KEY (`Intervento`)
    REFERENCES `progettouni`.`Intervento` (`idIntervento`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_Trattamento_Agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Trattamento_Intervento1_idx` ON `progettouni`.`Trattamento` (`Intervento` ASC);

CREATE INDEX `fk_Trattamento_Agente1_idx` ON `progettouni`.`Trattamento` (`Agente` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Url`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Url` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Url` (
  `idIndirizzo` INT(11) NOT NULL AUTO_INCREMENT,
  `Indirizzo` VARCHAR(200) NOT NULL,
  PRIMARY KEY (`IDIndirizzo`))
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE UNIQUE INDEX `Indirizzo` ON `progettouni`.`Url` (`Indirizzo` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`UrlPost`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`UrlPost` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`UrlPost` (
  `TimeStampPost` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `AccountPost` INT(11) NOT NULL,
  `Url` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStampPost`, `AccountPost`, `Url`),
  CONSTRAINT `fk_UrlPost_Post1`
    FOREIGN KEY (`TimeStampPost` , `AccountPost`)
    REFERENCES `progettouni`.`Post` (`TimeStamp` , `Account`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_UrlPost_Url1`
    FOREIGN KEY (`Url`)
    REFERENCES `progettouni`.`Url` (`idIndirizzo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_UrlPost_Post1_idx` ON `progettouni`.`UrlPost` (`TimeStampPost` ASC, `AccountPost` ASC);

CREATE INDEX `fk_UrlPost_Url1_idx` ON `progettouni`.`UrlPost` (`Url` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`UrlRisposta`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`UrlRisposta` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`UrlRisposta` (
  `TimeStampRisposta` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `AccountRisposta` INT(11) NOT NULL,
  `Url` INT(11) NOT NULL,
  PRIMARY KEY (`TimeStampRisposta`, `AccountRisposta`, `Url`),
  CONSTRAINT `fk_UrlRisposta_Risposta1`
    FOREIGN KEY (`TimeStampRisposta` , `AccountRisposta`)
    REFERENCES `progettouni`.`Risposta` (`TimeStamp` , `Account`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_UrlRisposta_Url1`
    FOREIGN KEY (`Url`)
    REFERENCES `progettouni`.`Url` (`idIndirizzo`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_UrlRisposta_Risposta1_idx` ON `progettouni`.`UrlRisposta` (`TimeStampRisposta` ASC, `AccountRisposta` ASC);

CREATE INDEX `fk_UrlRisposta_Url1_idx` ON `progettouni`.`UrlRisposta` (`Url` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`UtilizzoElemento`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`UtilizzoElemento` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`UtilizzoElemento` (
  `Modalita` VARCHAR(45) NULL DEFAULT NULL,
  `TipoConcimazione` INT(11) NOT NULL,
  `Elemento` INT(11) NOT NULL,
  PRIMARY KEY (`TipoConcimazione`, `Elemento`),
  CONSTRAINT `fk_UtilizzoElemento_TipoConcimazione1`
    FOREIGN KEY (`TipoConcimazione`)
    REFERENCES `progettouni`.`TipoConcimazione` (`idConcimazione`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_UtilizzoElemento_Elemento1`
    FOREIGN KEY (`Elemento`)
    REFERENCES `progettouni`.`Elemento` (`idElemento`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_UtilizzoElemento_Elemento1_idx` ON `progettouni`.`UtilizzoElemento` (`Elemento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`UtilizzoProdotto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`UtilizzoProdotto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`UtilizzoProdotto` (
  `Dosaggio` INT(10) UNSIGNED NOT NULL,
  `Prodotto` INT(11) NOT NULL,
  `Intervento` INT(11) NOT NULL,
  PRIMARY KEY (`Prodotto`, `Intervento`),
  CONSTRAINT `fk_UtilizzoProdotto_Prodotto1`
    FOREIGN KEY (`Prodotto`)
    REFERENCES `progettouni`.`Prodotto` (`idProdotto`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_UtilizzoProdotto_Intervento1`
    FOREIGN KEY (`Intervento`)
    REFERENCES `progettouni`.`Intervento` (`idIntervento`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_UtilizzoProdotto_Intervento1_idx` ON `progettouni`.`UtilizzoProdotto` (`Intervento` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Vaso`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Vaso` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Vaso` (
  `idVaso` INT(11) NOT NULL AUTO_INCREMENT,
  `PosizionePianta` INT(10) UNSIGNED NOT NULL,
  `Dimensione` INT(10) UNSIGNED NOT NULL,
  `Materiale` VARCHAR(45) NULL DEFAULT NULL,
  `Pianta` INT(11) NOT NULL,
  `Settore` INT(11) NOT NULL,
  PRIMARY KEY (`idVaso`),
  CONSTRAINT `fk_Vaso_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Vaso_Settore1`
    FOREIGN KEY (`Settore`)
    REFERENCES `progettouni`.`Settore` (`idSettore`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Vaso_Pianta1_idx` ON `progettouni`.`Vaso` (`Pianta` ASC);

CREATE INDEX `fk_Vaso_Settore1_idx` ON `progettouni`.`Vaso` (`Settore` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Voto`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Voto` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Voto` (
  `Giudizio` INT(11) NOT NULL,
  `AccountVotante` INT(11) NOT NULL,
  `TimeStampRisposta` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `AccountRisposta` INT(11) NOT NULL,
  PRIMARY KEY (`AccountVotante`,`TimeStampRisposta`,`AccountRisposta`),
  CONSTRAINT `fk_Voto_Account1`
    FOREIGN KEY (`AccountVotante`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Voto_Risposta1`
    FOREIGN KEY (`TimeStampRisposta` , `AccountRisposta`)
    REFERENCES `progettouni`.`Risposta` (`TimeStamp` , `Account`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

CREATE INDEX `fk_Voto_Risposta1_idx` ON `progettouni`.`Voto` (`TimeStampRisposta` ASC, `AccountRisposta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`PiantePreferite`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `progettouni`.`PiantePreferite` (
  `Account` INT NOT NULL,
  `Pianta` INT NOT NULL,
  PRIMARY KEY (`Account`, `Pianta`),
  CONSTRAINT `fk_PiantePreferite_Account1`
    FOREIGN KEY (`Account`)
    REFERENCES `progettouni`.`Account` (`idAccount`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_PiantePreferite_Pianta1`
    FOREIGN KEY (`Pianta`)
    REFERENCES `progettouni`.`Pianta` (`idPianta`)
    ON DELETE CASCADE
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


CREATE INDEX `fk_PiantePreferite_Account1_idx` ON `progettouni`.`PiantePreferite` (`Account` ASC);

CREATE INDEX `fk_PiantePreferite_Pianta1_idx` ON `progettouni`.`PiantePreferite` (`Pianta` ASC);


-- -----------------------------------------------------
-- Table `progettouni`.`Sintomatologia`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `progettouni`.`Sintomatologia` ;

CREATE TABLE IF NOT EXISTS `progettouni`.`Sintomatologia` (
  `Agente` INT(11) NOT NULL,
  `Sintomo` INT(11) NOT NULL,
  PRIMARY KEY (`Agente`, `Sintomo`),
  CONSTRAINT `fk_Sintomatologia_agente1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Agente` (`idAgente`)
    ON DELETE CASCADE
    ON UPDATE CASCADE,
  CONSTRAINT `fk_Sintomatologia_sintomo1`
    FOREIGN KEY (`Agente`)
    REFERENCES `progettouni`.`Sintomo` (`idSintomo`)
    ON DELETE CASCADE
    ON UPDATE CASCADE)
ENGINE = InnoDB
DEFAULT CHARACTER SET = latin1;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;


