SET @endDate='2019-12-20';
SELECT DISTINCT inscricao.patient_id,
       pid.identifier NID,
	   CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
	    ROUND(DATEDIFF(@endDate,pr.birthdate)/365) idade_actual,
	   pr.gender sexo,
	   inscricao.data_diagnostico,
	   inicio_tarv.data_inicio_tarv,
	   CASE regime.value_coded
						WHEN 6324 THEN 'TDF+3TC+EFV'
						WHEN 1651 THEN 'AZT+3TC+NVP'
						WHEN 6114 THEN 'AZT60+3TC+NVP(Douvir N Baby)'
						WHEN 23785 THEN 'TDF+3TC+DTG2'
						WHEN 23784 THEN 'TDF+3TC+DTG'
						WHEN 1703 THEN 'AZT+3TC+EFV'
						WHEN 1314 THEN 'AZT+3TC+LPV/r'
						WHEN 6243 THEN 'TDF+3TC+NVP'
						WHEN 6104 THEN 'ABC+3TC+EFV'
						WHEN 817 THEN 'ABC+3TC+AZT'
						WHEN 23786 THEN 'ABC+3TC+DTG'
						WHEN 23791 THEN 'TDF+3TC+ATV/r(2ª Linha)'
						WHEN 6108 THEN 'TDF+3TC+LPV/r(2ª Linha)'
						WHEN 21163 THEN 'AZT+3TC+LPV/r(2ª Linha)'
						WHEN 23792 THEN 'ABC+3TC+ATV/r(2ª Linha)'
						WHEN 1311 THEN 'ABC+3TC+LPV/r(2ª Linha)'
						WHEN 23790 THEN 'TDF+3TC+LPV/r+RTV (2ª Linha)'
						WHEN 23795 THEN 'ABC+3TC+ATV/r+RAL(2ª Linha Opt)'
						WHEN 23796 THEN 'TDF+3TC+ATV/r+RAL(2ª Linha Opt)'
						WHEN 6329 THEN 'TDF+3TC+RAL+DRV/r(3ª Linha)'
						WHEN 23797 THEN 'ABC+3TC++RAL+DRV/r(3ª Linha)'
						WHEN 23798 THEN '3TC+RAL+DRV/r(3ª Linha)'
						WHEN 6100 THEN 'AZT+3TC+LPV/r'
						WHEN 6116 THEN 'AZT+3TC+ABC'
						WHEN 6106 THEN 'ABC+3TC+LPV/r'
						WHEN 6105 THEN 'ABC+3TC+NVP'
						WHEN 23801 THEN 'AZT+3TC+RAL(2ª Linha)'
						WHEN 23802 THEN 'AZT+3TC+DRV/r(2ª Linha)'
						WHEN 23815 THEN 'AZT+3TC+DTG(2ª Linha)'
						WHEN 23803 THEN 'AZT+3TC+RAL+DRV/r(3ª Linha)'
					ELSE 'OUTRO' END AS ultimo_regime
					,cv.data_primeiro_carga data_primeira_cv_suprimida, cv.valor_primeira_carga primeira_cv_suprimida
					,mdc.data_inclusao_mdc, mdc.tipo_modelo
					,vu.valor_ultima_carga carga_viral_MDS
					,primeiro.primeiro_levantamento primeiro_levantamento_MDS
					,primeiro.segundo_levantamento segundo_levantamento_MDS
					,primeiro.ultimo_levantamento ultimo_levantamento_MDS
					#,ultimo.ultimo_levantamento ultimo_levantamento_MDS
					,fichaapss.primeira_fichaapss
					,fichaapss.segunda_fichaapss
					,fichaapss.ultima_fichaapss
FROM 
(	SELECT DISTINCT a.patient_id , a.data_abertura, a.data_diagnostico FROM 
	(SELECT 	p.patient_id,encounter_datetime data_abertura,o.value_datetime data_diagnostico
	FROM 	patient p 
			INNER JOIN encounter e ON e.patient_id=p.patient_id 
			 INNER JOIN obs o ON o.encounter_id=e.encounter_id
	WHERE 	e.voided=0 AND o.voided=0  AND p.voided=0 AND e.encounter_type IN (5,7) AND o.concept_id = 6123   AND 
			encounter_datetime<=@endDate 
	GROUP 	BY p.patient_id
	UNION
	SELECT 	p.patient_id,o1.value_datetime data_abertura,e.encounter_datetime data_diagnostico
	FROM 	patient p 
			INNER JOIN encounter e ON e.patient_id=p.patient_id 
			 INNER JOIN obs o ON o.encounter_id=e.encounter_id
			 INNER JOIN obs o1 ON (o1.encounter_id=e.encounter_id AND o1.voided=0 AND o1.concept_id=23891)
	WHERE 	e.voided=0 AND o.voided=0  AND p.voided=0 AND e.encounter_type = 53 AND ((o.concept_id = 23779 AND o.`value_coded`=703) OR (o.concept_id IN (1030,1040) AND o.value_coded IN (703,1065)))  AND 
			o1.value_datetime<=@endDate
	GROUP 	BY p.patient_id) a
	INNER JOIN
	
	(SELECT patient_id, MIN(data_abertura) data_abertura FROM
	(SELECT 	p.patient_id,encounter_datetime data_abertura,o.value_datetime data_diagnostico
	FROM 	patient p 
			INNER JOIN encounter e ON e.patient_id=p.patient_id 
			 INNER JOIN obs o ON o.encounter_id=e.encounter_id
	WHERE 	e.voided=0 AND o.voided=0  AND p.voided=0 AND e.encounter_type IN (5,7) AND o.concept_id = 6123   AND 
			encounter_datetime<=@endDate
	GROUP 	BY p.patient_id
	UNION
	SELECT 	p.patient_id,o1.value_datetime data_abertura,e.encounter_datetime data_diagnostico
	FROM 	patient p 
			INNER JOIN encounter e ON e.patient_id=p.patient_id 
			 INNER JOIN obs o ON o.encounter_id=e.encounter_id
			 INNER JOIN obs o1 ON (o1.encounter_id=e.encounter_id AND o1.voided=0 AND o1.concept_id=23891)
	WHERE 	e.voided=0 AND o.voided=0  AND p.voided=0 AND e.encounter_type = 53 AND ((o.concept_id = 23779 AND o.`value_coded`=703) OR (o.concept_id IN (1030,1040) AND o.value_coded IN (703,1065)))  AND 
			o1.value_datetime<=@endDate 
	GROUP 	BY p.patient_id) c
	GROUP BY patient_id) b
	ON a.patient_id=b.patient_id AND a.data_abertura=b.data_abertura
)inscricao 

LEFT JOIN
			(       SELECT pid1.*
					FROM patient_identifier pid1
					INNER JOIN
									(
													SELECT patient_id,MIN(patient_identifier_id) id
													FROM patient_identifier
													WHERE voided=0
													GROUP BY patient_id
									) pid2
					WHERE pid1.patient_id=pid2.patient_id AND pid1.patient_identifier_id=pid2.id
			) pid ON pid.patient_id=inscricao.patient_id
			LEFT JOIN person pr ON pr.person_id=inscricao.patient_id
                LEFT JOIN person_name pn ON inscricao.patient_id=pn.person_id AND pn.preferred=1
  LEFT JOIN 
  (	SELECT patient_id,MIN(data_inicio) data_inicio_tarv
		FROM
			(	SELECT    p.patient_id,MIN(e.encounter_datetime) data_inicio
                                                                FROM      patient p 
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id       
                                                                                                INNER JOIN obs o ON o.encounter_id=e.encounter_id
                                                                WHERE   e.voided=0 AND o.voided=0 AND p.voided=0 AND 
                                                                                                e.encounter_type IN (18,6,9) AND o.concept_id=1255 AND o.value_coded=1256 AND 
                                                                                                e.encounter_datetime<=@endDate 
                                                                GROUP BY p.patient_id
                                                                
                                
                                                                UNION
                                
                                                                SELECT    p.patient_id,MIN(value_datetime) data_inicio
                                                                FROM      patient p
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id
                                                                                                INNER JOIN obs o ON e.encounter_id=o.encounter_id
                                                                WHERE   p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (18,6,9,53) AND 
                                                                                                o.concept_id=1190 AND o.value_datetime IS NOT NULL AND 
                                                                                                o.value_datetime<=@endDate 
                                                                GROUP BY p.patient_id
 
                                                                UNION
 
                                                                SELECT    pg.patient_id,date_enrolled data_inicio
                                                                FROM      patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
                                                                WHERE   pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=@endDate 
                                                                
                                                                UNION
                                                                
                                                                
                                                  SELECT                e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
                                                  FROM                 patient p
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id
                                                  WHERE                               p.voided=0 AND e.encounter_type=18 AND e.voided=0 AND e.encounter_datetime<=@endDate 
                                                  GROUP BY         p.patient_id
                                                  UNION
                                                                SELECT  e.patient_id, MIN(o1.value_datetime) AS data_inicio 
           FROM    patient p
           INNER JOIN encounter e ON p.patient_id=e.patient_id
           INNER JOIN obs o1 ON e.encounter_id=o1.encounter_id
           INNER JOIN obs o ON e.encounter_id=o.encounter_id
           WHERE   p.voided=0  AND e.encounter_type=52 AND o.value_coded=1065 AND o1.voided=0 AND o1.concept_id=23866 AND o.voided=0 AND e.voided=0 AND o1.value_datetime<=@endDate 
           GROUP BY p.patient_id 
                         
			) inicio_real
		GROUP BY patient_id	
	) inicio_tarv ON inicio_tarv.patient_id=inscricao.patient_id
	
	LEFT JOIN obs regime ON regime.person_id=inscricao.patient_id AND regime.voided=0 AND regime.concept_id=1088
	LEFT JOIN
	(
            SELECT patient_id,MIN(data_primeiro_carga) data_primeiro_carga,MAX(value_numeric) valor_primeira_carga
			FROM	
				(	SELECT 	e.patient_id,
							MIN(o.obs_datetime) data_primeiro_carga
					FROM 	encounter e
							INNER JOIN obs o ON e.encounter_id=o.encounter_id
					WHERE 	e.encounter_type IN (13,6,9) AND e.voided=0 AND
							o.voided=0 AND o.concept_id=856 AND e.encounter_datetime<=@endDate 
					GROUP BY e.patient_id
				) primeiro_carga
				INNER JOIN obs o ON o.person_id=primeiro_carga.patient_id AND o.obs_datetime=primeiro_carga.data_primeiro_carga
			WHERE o.concept_id=856 AND o.voided=0
			GROUP BY patient_id
			HAVING MAX(value_numeric)<1000	
	)cv ON cv.patient_id=inscricao.patient_id
	
	LEFT JOIN
	(
          SELECT p.patient_id,MIN(e.encounter_datetime) data_inclusao_mdc,
                                       CASE o.concept_id
                                        WHEN 23724 THEN 'Gaac (GA)'
                                        WHEN 23725 THEN 'ABORDAGEM FAMILIAR (AF)'
                                        WHEN 23726 THEN 'CLUBES DE ADESÃO (CA)'
                                        WHEN 23727 THEN 'PARAGEM ÚNICA (PU)'
                                        WHEN 23729 THEN 'FLUXO RÁPIDO (FR)'
                                        WHEN 23730 THEN 'DISPENSA TRIMESTRAL (DT)'
                                        WHEN 23731 THEN 'DISPENSA COMUNITÁRIA (DC)'
                                        WHEN 23888 THEN 'DISPENSA SEMESTRAL'
                                        ELSE 'OUTRO MODELO'
                                        END AS tipo_modelo
					FROM 	patient p 
							INNER JOIN encounter e ON p.patient_id=e.patient_id	
							INNER JOIN obs o ON o.encounter_id=e.encounter_id
					WHERE 	e.voided=0 AND o.voided=0 AND p.voided=0 AND 
							e.encounter_type IN (18,6,9) AND 
							o.concept_id IN (23724, 23725,23726,23727,23729,23730,23731,23732,23888)
							AND o.value_coded=1256
							AND e.encounter_datetime<=@endDate 
					GROUP BY p.patient_id	
	) mdc ON mdc.patient_id=inscricao.patient_id
	
	LEFT JOIN
	(
          SELECT patient_id,MIN(data_ultima_carga) data_ultima_carga,MAX(value_numeric) valor_ultima_carga
			FROM	
				(	SELECT 	e.patient_id,
							MAX(o.obs_datetime) data_ultima_carga
					FROM 	encounter e
							INNER JOIN obs o ON e.encounter_id=o.encounter_id
					WHERE 	e.encounter_type IN (13,6,9) AND e.encounter_datetime<=@endDate 
					GROUP BY e.patient_id
				) ultima_carga
				INNER JOIN obs o ON o.person_id=ultima_carga.patient_id AND o.obs_datetime=ultima_carga.data_ultima_carga
			WHERE o.concept_id=856 AND o.voided=0 
			GROUP BY patient_id	
	)vu ON vu.patient_id=inscricao.patient_id
	
	LEFT JOIN
	(
           SELECT       visita.patient_id,
			visita.primeiro_levantamento,
			visita.segundo_levantamento,
			visita.ultimo_levantamento		
			
	FROM
		(	SELECT patient_id,MIN(encounter_datetime) primeiro_levantamento, encounter_datetime segundo_levantamento, MAX(encounter_datetime) ultimo_levantamento,location_id,encounter_id
			FROM encounter 
			WHERE encounter_type=18 AND voided=0 AND encounter_datetime<=@endDate
			GROUP BY patient_id
			HAVING encounter_datetime BETWEEN MIN(encounter_datetime) AND MAX(encounter_datetime) 
		) visita
		 INNER JOIN
		 (
                   	SELECT p.patient_id,encounter_datetime	
                   	FROM 	patient p 
							INNER JOIN encounter e ON p.patient_id=e.patient_id	
							INNER JOIN obs o ON o.encounter_id=e.encounter_id
					WHERE 	e.voided=0 AND o.voided=0 AND p.voided=0 AND 
							e.encounter_type IN (18,6,9) #AND 
							#o.concept_id IN (23724, 23725,23726,23727,23729,23730,23731,23732,23888)
							#AND o.value_coded=1256
							AND e.encounter_datetime<=@endDate 
					GROUP BY p.patient_id                                               	 
		 ) imd ON imd.patient_id=visita.patient_id
		
	) primeiro ON primeiro.patient_id=mdc.patient_id 

   LEFT JOIN
     
     (SELECT 	p.patient_id,MIN(encounter_datetime) primeira_fichaapss, encounter_datetime segunda_fichaapss,MAX(encounter_datetime) ultima_fichaapss
	FROM 	patient p 
	INNER JOIN encounter e ON e.patient_id=p.patient_id
	WHERE 	p.voided=0 AND e.voided=0 AND e.encounter_type IN(34,35) AND form_id=164 AND e.encounter_datetime<=@endDate
	GROUP BY p.patient_id
	HAVING encounter_datetime BETWEEN MIN(encounter_datetime) AND MAX(encounter_datetime)
    ) fichaapss ON mdc.patient_id=fichaapss.patient_id   
      WHERE fichaapss.primeira_fichaapss>=mdc.data_inclusao_mdc
      

