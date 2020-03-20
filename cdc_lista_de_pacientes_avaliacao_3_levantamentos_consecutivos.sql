-- SQL desenhado por Eurico Jose, FGH
-- Modificado por Xavier Nhagumbe Abt Associates Inc.
select inicio_real.patient_id,
pid.identifier NID,
concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
		 round(datediff(:endDate,pr.birthdate)/365) idade_actual,
		 pr.gender,
		 inicio_real.data_inicio,
		 if(gravida.patient_id is not null,'SIM','') gravida,
		 consulta.ultimo_segmento data_ultimo,
         consulta.value_datetime proximo_consulta,
		 ultimo.ultimo_levantamento,
         ultimo.value_datetime data_proximo,
		 saida_real.encounter_datetime data_saida,
         if(saida_real.estado is not null,saida_real.estado,if(ultimo.value_datetime is not null,if(datediff(:endDate,ultimo.value_datetime)>60,'ABANDONO NAO NOTIFICADO','ACTIVO'),'SEM FILA' )) estado,
		 if(count(e.patient_id)>=3,'SIM','') as levantou
from
(	select patient_id,data_inicio
	from
	(	Select patient_id,min(data_inicio) data_inicio
		from
				(	Select 	p.patient_id,min(e.encounter_datetime) data_inicio
					from 	patient p 
							inner join encounter e on p.patient_id=e.patient_id	
							inner join obs o on o.encounter_id=e.encounter_id
					where 	e.voided=0 and o.voided=0 and p.voided=0 and 
							e.encounter_type in (18,6,9,53) and o.concept_id=1255 and o.value_coded=1256 and 
							e.encounter_datetime<=:endDate and e.location_id=:location
					group by p.patient_id
			
					union
			
					Select 	p.patient_id,min(value_datetime) data_inicio
					from 	patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join obs o on e.encounter_id=o.encounter_id
					where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9,53) and 
							o.concept_id=1190 and o.value_datetime is not null and 
							o.value_datetime<=:endDate and e.location_id=:location
					group by p.patient_id

					union

					select 	pg.patient_id,date_enrolled data_inicio
					from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
					where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=:endDate and location_id=:location
					
					union
					
					
				  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio 
				  FROM 		patient p
							inner join encounter e on p.patient_id=e.patient_id
				  WHERE		p.voided=0 and e.encounter_type=18 AND e.voided=0 and e.encounter_datetime<=:endDate and e.location_id=:location
				  GROUP BY 	p.patient_id				
					
					
				) inicio
			group by patient_id	
	)inicio1
	where data_inicio between date_add(date_add(:endDate, interval -4 month), interval 1 day) and date_add(:endDate, interval -3 month)
) inicio_real

left join
			(       select pid1.*
					from patient_identifier pid1
					inner join
									(
													select patient_id,min(patient_identifier_id) id
													from patient_identifier
													where voided=0
													group by patient_id
									) pid2
					where pid1.patient_id=pid2.patient_id and pid1.patient_identifier_id=pid2.id
			) pid on pid.patient_id=inicio_real.patient_id
				left join person pr on pr.person_id=inicio_real.patient_id
                left join person_name pn on inicio_real.patient_id=pn.person_id and pn.preferred=1
				
	left join 
	(
	
		Select 	p.patient_id
		from 	patient p 
				inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on e.encounter_id=o.encounter_id
		where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1982 and value_coded=44 and 
				e.encounter_type in (5,6,53) and e.encounter_datetime <=:endDate and e.location_id=:location

		union		
				
		Select 	p.patient_id
		from 	patient p inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on e.encounter_id=o.encounter_id
		where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1279 and 
				e.encounter_type in (5,6,53) and e.encounter_datetime <=:endDate and e.location_id=:location


		union		
		-- gravidez		
		Select 	p.patient_id
		from 	patient p inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on e.encounter_id=o.encounter_id
		where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1600 and 
				e.encounter_type in (5,6,53) and e.encounter_datetime <=:endDate and e.location_id=:location		
				
		union
		
        -- PTV		
		select 	pp.patient_id
		from 	patient_program pp 
		where 	pp.program_id=8 and pp.voided=0 and 
				pp.date_enrolled <=:endDate and pp.location_id=:location
	
	) gravida on gravida.patient_id= inicio_real.patient_id	
	
	left join	
	
	(	select ultimo.patient_id,ultimo.ultimo_segmento,o.value_datetime
		from
			(	Select 	p.patient_id,max(encounter_datetime) ultimo_segmento
				from 	patient p 
						inner join encounter e on e.patient_id=p.patient_id
				where 	p.voided=0 and e.voided=0 and e.encounter_type in(6,9) and 
						e.location_id=:location and e.encounter_datetime<=:endDate
				group by p.patient_id
			) ultimo 
			left join obs o on o.person_id=ultimo.patient_id and ultimo.ultimo_segmento=o.obs_datetime and o.voided=0 and o.concept_id=1410		
	) consulta on inicio_real.patient_id=consulta.patient_id
	
	left join
	(	select max_frida.patient_id,max_frida.ultimo_levantamento,o.value_datetime
		from
			(	Select 	p.patient_id,max(encounter_datetime) ultimo_levantamento
				from 	patient p 
						inner join encounter e on e.patient_id=p.patient_id
				where 	p.voided=0 and e.voided=0 and e.encounter_type=18 and 
						e.location_id=:location and e.encounter_datetime<=:endDate
				group by p.patient_id
			) max_frida 
			left join obs o on o.person_id=max_frida.patient_id and max_frida.ultimo_levantamento=o.obs_datetime and o.voided=0 and o.concept_id=5096		
	) ultimo on inicio_real.patient_id=ultimo.patient_id
	
	left join
	(	select 	pg.patient_id,ps.start_date encounter_datetime,location_id,
				case ps.state
				when 7 then 'TRANSFERIDO PARA'
				when 8 then 'SUSPENSO'
				when 9 then 'ABANDONO'
				when 10 then 'OBITO'
				else 'OUTRO' end as estado
		from 	patient p 
				inner join patient_program pg on p.patient_id=pg.patient_id
				inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
		where 	pg.voided=0 and ps.voided=0 and p.voided=0 and ps.start_date<=:endDate and 
				pg.program_id=2 and ps.state in (7,8,9,10) and ps.end_date is null and location_id=:location
	) saida_real on inicio_real.patient_id=saida_real.patient_id	
 
 left join encounter e on e.patient_id=inicio_real.patient_id
and 	e.voided=0 and e.encounter_type=18 and e.location_id=:location and 
		e.encounter_datetime between inicio_real.data_inicio and date_add(inicio_real.data_inicio, interval 99 day) and
		
		inicio_real.patient_id not in 
		(
			select 	pg.patient_id
			from 	patient p 
					inner join patient_program pg on p.patient_id=pg.patient_id
					inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
			where 	pg.voided=0 and ps.voided=0 and p.voided=0 and 
					pg.program_id=2 and ps.state=29 and ps.start_date=pg.date_enrolled and 
					ps.start_date between date_add(date_add(:endDate, interval -4 month), interval 1 day) and date_add(:endDate, interval -3 month) and location_id=:location
		)
group by inicio_real.patient_id 
