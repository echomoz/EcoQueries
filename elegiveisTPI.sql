-- SQL desenhado por Eurico Jose, FGH
-- Modificado por Xavier Nhagumbe Abt Associates Inc.
SET @startDate='2020-01-21',@endDate='2020-02-20';
SELECT us.name,	inscricao.patient_id,
		        pid.identifier NID,
			CONCAT(IFNULL(pn.given_name,''),' ',IFNULL(pn.middle_name,''),' ',IFNULL(pn.family_name,'')) AS 'NomeCompleto',
			pe.gender,
			ROUND(DATEDIFF(@endDate,pe.birthdate)/365) idade_actual,
		        data_inicio_inh,
		        data_fim_inh,
		        inicio_tarv.data_inicio_tarv,
		        IF(data_fim_inh IS NULL,DATEDIFF(@endDate,data_inicio_inh),NULL) dias_inh,
		        IF(data_fim_inh IS NULL,ROUND(DATEDIFF(@endDate,data_inicio_inh)/30),NULL) meses_inh
FROM
(	SELECT 	p.patient_id,e.encounter_datetime data_inscricao,e.encounter_id
			FROM 	patient p
					INNER JOIN encounter e ON p.patient_id=e.patient_id
			WHERE 	e.encounter_type IN (32,53) AND e.voided=0 AND p.voided=0 AND e.encounter_datetime BETWEEN @startDate AND @endDate
) inscricao
INNER JOIN
 ( SELECT DISTINCT e.patient_id, l.name NAME
	FROM encounter e INNER JOIN location l ON e.location_id=l.location_id
)us ON us.patient_id=inscricao.patient_id 
LEFT JOIN
	(	SELECT ultimo.patient_id,ultimo.ultimo_segmento,o.value_datetime
		FROM
			(	SELECT 	p.patient_id,MAX(encounter_datetime) ultimo_segmento
				FROM 	patient p 
						INNER JOIN encounter e ON e.patient_id=p.patient_id
				WHERE 	p.voided=0 AND e.voided=0 AND e.encounter_type IN(6,9) AND e.encounter_datetime<=@endDate
				GROUP BY p.patient_id
			) ultimo 
			LEFT JOIN obs o ON o.person_id=ultimo.patient_id AND ultimo.ultimo_segmento=o.obs_datetime AND o.voided=0 AND o.concept_id=1410		
	) consulta ON inscricao.patient_id=consulta.patient_id
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
LEFT JOIN person_name pn ON pn.person_id=inscricao.patient_id AND pn.voided=0	
LEFT JOIN person pe ON pe.person_id=inscricao.patient_id AND pe.voided=0
LEFT JOIN

(	SELECT 	p.patient_id,MAX(obs_datetime) data_rastreio
		FROM 	patient p
				INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON o.encounter_id=e.encounter_id
		WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND p.voided=0 AND
				((o.concept_id=6257 AND o.value_coded=1066) OR (o.concept_id=23758 AND value_coded=1066)) AND 
				e.encounter_datetime BETWEEN @startDate AND @endDate
		GROUP BY p.patient_id
) rastreioTB_neg ON inscricao.patient_id=rastreioTB_neg.patient_id
	
	LEFT JOIN
	
	(	SELECT 	p.patient_id,MAX(obs_datetime) data_rastreio
		FROM 	patient p
				INNER JOIN encounter e ON p.patient_id=e.patient_id
				INNER JOIN obs o ON o.encounter_id=e.encounter_id
		WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND p.voided=0 AND
				((o.concept_id=6257 AND o.value_coded=1065) OR (o.concept_id=23758 AND value_coded=1065)) AND 
				e.encounter_datetime BETWEEN @startDate AND @endDate
		GROUP BY p.patient_id
	) rastreioTB_pos ON inscricao.patient_id=rastreioTB_pos.patient_id
	LEFT JOIN
	(	SELECT patient_id,data_investigacao,IF(value_coded IN (703,1065),'POSITIVO','NEGATIVO') resultado
		FROM
		(	SELECT 	p.patient_id,MAX(obs_datetime) data_investigacao
				FROM 	patient p
						INNER JOIN encounter e ON p.patient_id=e.patient_id
						INNER JOIN obs o ON o.encounter_id=e.encounter_id
				WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND p.voided=0 AND
						o.concept_id IN (6277,23761) AND 
						e.encounter_datetime BETWEEN @startDate AND @endDate
				GROUP BY p.patient_id
		) max_investigacao
		INNER JOIN obs ON obs.person_id=max_investigacao.patient_id
		WHERE max_investigacao.data_investigacao=obs.obs_datetime AND obs.concept_id IN (6277,23761) AND voided=0 
	) investigacaoTB ON inscricao.patient_id=investigacaoTB.patient_id
	
	LEFT JOIN
	(SELECT inicio_inh.patient_id,data_inicio_inh, data_fim_inh FROM
	(	SELECT patient_id,MAX(data_inicio_inh) data_inicio_inh
		FROM
		(	SELECT 	p.patient_id,o.value_datetime data_inicio_inh
			FROM 	patient p
					INNER JOIN encounter e ON p.patient_id=e.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9) AND e.voided=0 AND o.voided=0 AND p.voided=0 AND
					o.concept_id=6128 AND 
					o.value_datetime BETWEEN @startDate AND @endDate
			UNION
		   SELECT 	e.patient_id,
					e.encounter_datetime data_inicio_inh
		   FROM 	patient p
					INNER JOIN encounter e ON e.patient_id=p.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
		   WHERE 	e.encounter_datetime BETWEEN @startDate AND @endDate AND e.voided=0 AND p.voided=0  AND e.encounter_type IN (6,9) AND o.concept_id=6122 AND o.value_coded = 1256 AND o.voided=0					
		  
		) inicio1
		GROUP BY patient_id
	) inicio_inh
	
	LEFT JOIN
	(	SELECT patient_id,MAX(data_fim_inh) data_fim_inh
		FROM
		(	SELECT 	p.patient_id,o.value_datetime data_fim_inh
			FROM 	patient p
					INNER JOIN encounter e ON p.patient_id=e.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
			WHERE 	e.encounter_type IN (6,9,53) AND e.voided=0 AND o.voided=0 AND p.voided=0 AND
					o.concept_id=6129 
				UNION
			
		   SELECT 	e.patient_id,
					e.encounter_datetime data_fim_inh
		   FROM 	patient p
					INNER JOIN encounter e ON e.patient_id=p.patient_id
					INNER JOIN obs o ON o.encounter_id=e.encounter_id
		   WHERE 	e.encounter_datetime <= @endDate AND e.voided=0 AND p.voided=0  AND e.encounter_type IN (6,9) AND o.concept_id=6122 AND o.value_coded = 1267 AND o.voided=0					
			
		) fim1
		GROUP BY patient_id
	) fim_inh ON inicio_inh.patient_id=fim_inh.patient_id  AND data_fim_inh>data_inicio_inh
	) inh ON inscricao.patient_id=inh.patient_id
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
	
WHERE IF(rastreioTB_neg.patient_id IS NOT NULL AND (data_fim_inh IS NULL OR data_fim_inh>@endDate),'SIM',
	IF(rastreioTB_pos.patient_id IS NOT NULL AND investigacaoTB.resultado='NEGATIVO' AND (data_fim_inh IS NULL OR data_fim_inh>@endDate),'SIM','NAO')
	) = 'SIM'	