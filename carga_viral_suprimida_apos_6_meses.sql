-- SQL desenhado por Eurico Jose, FGH
-- Modificado por Xavier Nhagumbe Abt Associates Inc.
SELECT DISTINCT inicio.patient_id,
           pid.identifier NID,
		 CONCAT(pn.given_name,' ',pn.family_name) AS NomeCompleto,
		 pe.gender,
		ROUND(DATEDIFF(:endDate,pe.birthdate)/365) idade_actual,
		IF(ROUND(DATEDIFF(:endDate,pe.birthdate)/365) <5,'Criança (<5 anos)','') crianca,
		 inicio.data_inicio,
		 carga_viral.value_numeric cv,
		 carga_viral.encounter_datetime data_cv,
		  IF(gravida.patient_id IS NOT NULL,'SIM','') gravida,
		  consulta.value_datetime proxima_consulta,
		  ultimo.value_datetime proximo_lev,
		 pa.county_district AS 'Distrito',
		pa.address2 AS 'PAdministrativo',
		pa.address6 AS 'Localidade',
		pa.address5 AS 'Bairro',
		pa.address1 AS 'PontoReferencia',
		pat.value AS 'contacto',
		pessoa_referencia.ref AS 'pessoa'
FROM
(        SELECT patient_id,MIN(data_inicio) data_inicio
                                FROM
                                                (              SELECT    p.patient_id,MIN(e.encounter_datetime) data_inicio
                                                                FROM      patient p 
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id       
                                                                                                INNER JOIN obs o ON o.encounter_id=e.encounter_id
                                                                WHERE   e.voided=0 AND o.voided=0 AND p.voided=0 AND 
                                                                                                e.encounter_type IN (18,6,9) AND o.concept_id=1255 AND o.value_coded=1256 AND 
                                                                                                e.encounter_datetime<=:endDate AND e.location_id=:location
                                                                GROUP BY p.patient_id
                                                                UNION
                                                                SELECT    p.patient_id,MIN(e.encounter_datetime) data_inicio
                                                                FROM      patient p 
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id       
                                                                                                INNER JOIN obs o ON o.encounter_id=e.encounter_id
                                                                WHERE   e.voided=0 AND o.voided=0 AND p.voided=0 AND 
                                                                                                e.encounter_type = 52 AND o.concept_id=23865 AND o.value_coded=1065 AND 
                                                                                                e.encounter_datetime<=:endDate AND e.location_id=:location
                                                                GROUP BY p.patient_id
                                
                                                                UNION
                                
                                                                SELECT    p.patient_id,MIN(value_datetime) data_inicio
                                                                FROM      patient p
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id
                                                                                                INNER JOIN obs o ON e.encounter_id=o.encounter_id
                                                                WHERE   p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (18,6,9,53) AND 
                                                                                                o.concept_id=1190 AND o.value_datetime IS NOT NULL AND 
                                                                                                o.value_datetime<=:endDate AND e.location_id=:location
                                                                GROUP BY p.patient_id
 
                                                                UNION
 
                                                                SELECT    pg.patient_id,date_enrolled data_inicio
                                                                FROM      patient p INNER JOIN patient_program pg ON p.patient_id=pg.patient_id
                                                                WHERE   pg.voided=0 AND p.voided=0 AND program_id=2 AND date_enrolled<=:endDate AND location_id=:location
                                                                
                                                                UNION
                                                                
                                                                
                                                  SELECT                e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
                                                  FROM                 patient p
                                                                                                INNER JOIN encounter e ON p.patient_id=e.patient_id
                                                  WHERE                               p.voided=0 AND e.encounter_type=18 AND e.voided=0 AND e.encounter_datetime<=:endDate AND e.location_id=:location
                                                  GROUP BY         p.patient_id
                                                                                
                                                                
                                                                
                                                ) inicio_real
                                GROUP BY patient_id        
                )inicio
					
			 INNER JOIN patient_identifier pid ON pid.patient_id=inicio.patient_id AND pid.identifier_type IN(2,13) AND pid.preferred=1
             LEFT JOIN person_name pn ON inicio.patient_id=pn.person_id AND pn.preferred=1	
			 LEFT JOIN person_address pa ON pa.person_id=inicio.patient_id AND pa.preferred=1 AND pa.voided=0
			 LEFT JOIN person_attribute pat ON pat.person_id=inicio.patient_id AND pat.person_attribute_type_id=9
			 INNER JOIN person pe ON pe.person_id=inicio.patient_id

              LEFT JOIN 
		   (	  SELECT patient_id,IF(o.value_text IS NOT NULL,o.value_text,o1.value_text) AS ref
			               FROM encounter e
			         INNER JOIN obs o ON o.encounter_id=e.encounter_id
			         LEFT JOIN obs o1 ON o1.encounter_id=e.encounter_id			
			         WHERE encounter_type IN (5,7,53) AND (o.concept_id=1611 OR o1.concept_id=6224) AND o.voided=0 AND o1.voided=0 AND e.location_id=:location 
			         GROUP BY patient_id
		    ) pessoa_referencia ON pessoa_referencia.patient_id=inicio.patient_id
			
				LEFT JOIN 
	(
	
		SELECT 	p.patient_id
		FROM 	patient p 
				INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON e.encounter_id=o.encounter_id
		WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND concept_id=1982 AND value_coded IN (44,1465) AND 
				e.encounter_type IN (5,6) AND e.encounter_datetime <=:endDate AND e.location_id=:location

		UNION
		
		
		SELECT 	p.patient_id
		FROM 	patient p 
				INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON e.encounter_id=o.encounter_id
		WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND concept_id=5272 AND value_coded=1065 AND 
				e.encounter_type =53 AND e.encounter_datetime <=:endDate AND e.location_id=:location

		UNION	
				
		SELECT 	p.patient_id
		FROM 	patient p INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON e.encounter_id=o.encounter_id
		WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND concept_id=1279 AND 
				e.encounter_type IN (5,6) AND e.encounter_datetime <=:endDate AND e.location_id=:location


		UNION		
				
		SELECT 	p.patient_id
		FROM 	patient p INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON e.encounter_id=o.encounter_id
		WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND concept_id=1600 AND 
				e.encounter_type IN (5,6) AND e.encounter_datetime <=:endDate AND e.location_id=:location		
				
		UNION
				
		SELECT 	pp.patient_id
		FROM 	patient_program pp 
		WHERE 	pp.program_id=8 AND pp.voided=0 AND 
				pp.date_enrolled <=:endDate AND pp.location_id=:location
	
	) gravida ON gravida.patient_id= inicio.patient_id
	
	LEFT JOIN
	(	SELECT ultimo.patient_id,ultimo.ultimo_segmento,o.value_datetime
		FROM
			(	SELECT 	p.patient_id,MAX(encounter_datetime) ultimo_segmento
				FROM 	patient p 
						INNER JOIN encounter e ON e.patient_id=p.patient_id
				WHERE 	p.voided=0 AND e.voided=0 AND e.encounter_type IN(6,9) AND 
						e.location_id=:location AND e.encounter_datetime<=:endDate
				GROUP BY p.patient_id
			) ultimo 
			LEFT JOIN obs o ON o.person_id=ultimo.patient_id AND ultimo.ultimo_segmento=o.obs_datetime AND o.voided=0 AND o.concept_id=1410		
	) consulta ON inicio.patient_id=consulta.patient_id
	
	LEFT JOIN
	(	SELECT DISTINCT max_frida.patient_id,max_frida.ultimo_levantamento,o.value_datetime
		FROM
			(	SELECT 	p.patient_id,MAX(encounter_datetime) ultimo_levantamento
				FROM 	patient p 
						INNER JOIN encounter e ON e.patient_id=p.patient_id
						WHERE 	p.voided=0 AND e.voided=0 AND e.encounter_type=18 AND 
						e.location_id=:location AND e.encounter_datetime<=:endDate
				GROUP BY p.patient_id
				UNION
				SELECT 	p.patient_id,MAX(encounter_datetime) ultimo_levantamento
				FROM 	patient p 
						INNER JOIN encounter e ON e.patient_id=p.patient_id
						LEFT JOIN obs o ON e.encounter_id=o.encounter_id
				WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type=52 AND o.concept_id=23865 AND o.value_coded=1065  AND 
						e.location_id=:location AND e.encounter_datetime<=:endDate
				GROUP BY p.patient_id
			) max_frida 
			LEFT JOIN obs o ON o.person_id=max_frida.patient_id AND max_frida.ultimo_levantamento=o.obs_datetime AND o.voided=0 AND o.concept_id=5096		
	) ultimo ON inicio.patient_id=ultimo.patient_id

               LEFT JOIN 
			     (
				             SELECT p.patient_id, o.value_numeric,e.encounter_datetime
                            FROM 	patient p
		                      INNER JOIN encounter e ON p.patient_id=e.patient_id
		                      INNER JOIN obs o ON e.encounter_id=o.encounter_id
                              WHERE 	p.voided=0 AND e.voided=0 AND o.voided=0 AND e.encounter_type IN (13,6,9,53) AND 
		                            o.concept_id=856 AND o.value_numeric <1000 AND o.value_numeric IS NOT NULL AND 
		                            e.encounter_datetime <=:endDate AND e.location_id=:location
				  )carga_viral ON carga_viral.patient_id=inicio.patient_id
			
                           WHERE DATEDIFF(:endDate,data_inicio)>=180 AND carga_viral.value_numeric <1000

