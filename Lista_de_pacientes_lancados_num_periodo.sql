select 	inscricao.patient_id,
        pid.identifier as NID,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) as 'NomeCompleto',
		inscricao.gender as sexo,
		inscricao.dead,
		inscricao.death_date,
		inscricao.idade_abertura,
		inscricao.idade_actual as idade,
		inscricao.data_abertura as parteA,
		parteb. data_parteB as parteB,
		proveniencia.referencia as referencia,
		pretarv.data_inscricao data_inscricao_pretarv,
		pretarv.livro pretarv_livro,
		pretarv.pagina pretarv_pagina,
		pretarv.linha pretarv_linha,
		inscrito_cuidado.date_enrolled inscricao_cuidado,
		if(saida_pre_tarv.estado is not null,saida_pre_tarv.estado,if(consulta.value_datetime is not null,if(datediff(:endDate,consulta.value_datetime)>60,'ABANDONO NAO NOTIFICADO','ACTIVO'),'SEM DATA DA PROXIMA CONSULTA' )) estado_pre_tarv,
		inicio_real.data_inicio as data_inicio,
		
		tarv.data_inscricao data_inscricao_tarv,
		tarv.livro tarv_livro,
		tarv.pagina tarv_pagina,
		tarv.linha tarv_linha,
		inscrito_tratamento.date_enrolled inscricao_tratamento,
		if(saida_tarv.estado is not null,saida_tarv.estado,if(ultimo.value_datetime is not null,if(datediff(:endDate,ultimo.value_datetime)>60,'ABANDONO NAO NOTIFICADO','ACTIVO'),'SEM FILA' )) estado_tarv,
		consulta.ultimo_segmento data_ultimo_segmento,
		consulta.value_datetime data_proximo_segmento,
		ultimo.ultimo_levantamento data_ultimo,
		ultimo.value_datetime data_proximo,
		cd4.value_numeric as CD4,
		estadio.valor_estadio as estadio,
		inscrito_tuberculose.date_enrolled as programa_tb,
		inscrito_ptv.date_enrolled as programa_ptv,
		usr.username as utilizador
		
		
from		
		(Select 	e.patient_id, e.encounter_datetime data_abertura,
				gender,
				dead,
				death_date,
				e.creator,
				e.date_created,
				round(datediff(e.encounter_datetime,pe.birthdate)/365) idade_abertura,
				round(datediff(:endDate,pe.birthdate)/365) idade_actual,
				e.location_id
		from 	patient p			
				inner join encounter e on e.patient_id=p.patient_id
				inner join person pe on pe.person_id=p.patient_id			
		where 	e.encounter_type in (5,7,53) and p.voided=0 and e.voided=0 and pe.voided=0 and e.location_id=:location
		          and DATE(e.date_created) between :startDate and :endDate
		) inscricao
		left join person_address pe on pe.person_id=inscricao.patient_id and pe.preferred=1 and pe.voided=0
		left join person_name pn on pn.person_id=inscricao.patient_id and pn.preferred=1 and pn.voided=0
		left join users usr on usr.user_id= inscricao.creator
		
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
			) pid on pid.patient_id=inscricao.patient_id
		left join
		
		(select e.patient_id,
		         min(encounter_datetime) data_parteB,
				 e.location_id
				 
			from patient p
				 inner join encounter e on e.patient_id=p.patient_id
				 
			where encounter_type in (1,3) and e.voided=0 and e.location_id=:location
			
			group by p.patient_id
		) parteb on parteb.patient_id=inscricao.patient_id
		
		left join 		
		(Select patient_id,min(data_inicio) data_inicio
		from
			(	Select 	p.patient_id,
						min(e.encounter_datetime) data_inicio
				from 	patient p 
						inner join encounter e on p.patient_id=e.patient_id	
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and o.voided=0 and p.voided=0 and 
						e.encounter_type in (6,9) and o.concept_id=1255 and o.value_coded=1256 and e.location_id=:location
				group by p.patient_id				
				union	
				Select 	p.patient_id,
						min(value_datetime) data_inicio
				from 	patient p
						inner join encounter e on p.patient_id=e.patient_id
						inner join obs o on e.encounter_id=o.encounter_id
				where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (6,9) and 
						o.concept_id=1190 and o.value_datetime is not null  and o.location_id=:location
				group by p.patient_id
			) inicio
		group by patient_id
		) inicio_real on inscricao.patient_id=inicio_real.patient_id
		
		left join
		(	select 	p.patient_id,
					case o.value_coded
					when 1595 then 'INTERNAMENTO'
					when 1596 then 'CONSULTA EXTERNA'
					when 1414 then 'PNCT'
					when 1597 then 'ATS'
					when 1987 then 'SAAJ'
					when 1598 then 'PTV'
					when 1872 then 'CCR'
					when 1275 then 'CENTRO DE SAUDE'
					when 1984 then 'HR'
					when 1599 then 'PROVEDOR PRIVADO'
					when 1932 then 'PROFISSIONAL DE SAUDE'
					when 1387 then 'LABORATÓRIO'
					when 1386 then 'CLINICA MOVEL'
					when 6245 then 'ATSC'
					when 1699 then 'CUIDADOS DOMICILIARIOS'
					when 2160 then 'VISITA DE BUSCA'
					when 6288 then 'SMI'
					when 5484 then 'APOIO NUTRICIONAL'
					when 6155 then 'MEDICO TRADICIONAL'
					when 1044 then 'PEDIATRIA'
					when 6303 then 'VGB'
					when 6304 then 'ATIP'
					when 6305 then 'OBC'
					else 'OUTRO' end as referencia
			from 	patient p
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on o.encounter_id=e.encounter_id
			where 	encounter_type in (5,7) and e.voided=0 and e.location_id=:location
					and p.voided=0 and o.voided=0 and o.concept_id=1594					
		)proveniencia on proveniencia.patient_id=inscricao.patient_id
		
		left join                
		(   select registo_pre_tarv.patient_id,data_inscricao,registo_pre_tarv.location_id,
				   if(livro.value_coded=6259,'LIVRO 1',if(livro.value_coded=6260,'LIVRO 2','')) livro,
				   pagina.value_numeric pagina,
				   linha.value_numeric linha,
				   registo_pre_tarv.local_livro_pretarv
   
			from
				(   select  p.patient_id,
							e.location_id,
							l.name local_livro_pretarv,
							e.encounter_datetime data_inscricao,
							e.encounter_id
					from  	patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join location l on e.location_id=l.location_id                                                                                                                                                       
					where 	e.encounter_type=32 and e.voided=0 and p.voided=0 and 
							e.encounter_datetime<=:endDate and e.location_id=:location
				) registo_pre_tarv
			   left join obs livro on livro.encounter_id=registo_pre_tarv.encounter_id and livro.voided=0 and livro.concept_id=6263
			   left join obs pagina on pagina.encounter_id=registo_pre_tarv.encounter_id and pagina.voided=0 and pagina.concept_id=6265
			   left join obs linha on linha.encounter_id=registo_pre_tarv.encounter_id and linha.voided=0 and linha.concept_id=6267
        ) pretarv on inscricao.patient_id=pretarv.patient_id and inscricao.location_id=pretarv.location_id
		
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
	) consulta on inscricao.patient_id=consulta.patient_id
		left join
		(
			select 	pg.patient_id,date_enrolled
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id=1 and location_id=:location
		) inscrito_cuidado on inscrito_cuidado.patient_id=inscricao.patient_id
		
		left join	
	(	select 	pg.patient_id,ps.start_date encounter_datetime,location_id,
				case ps.state
				when 2 then 'ABANDONO'
				when 3 then 'TRANSFERIDO PARA'
				when 4 then 'INICIO TARV'
				when 5 then 'OBITO'
				else 'OUTRO' end as estado
		from 	patient p 
				inner join patient_program pg on p.patient_id=pg.patient_id
				inner join patient_state ps on pg.patient_program_id=ps.patient_program_id
		where 	pg.voided=0 and ps.voided=0 and p.voided=0 and ps.start_date<=:endDate and 
				pg.program_id=1 and ps.state in (2,3,4,5) and ps.end_date is null and location_id=:location
	) saida_pre_tarv on inscricao.patient_id=saida_pre_tarv.patient_id	
	
	left join 
        (   select  registo_tarv.patient_id,data_inscricao,
                    if(livro.value_coded=6261,'LIVRO 1',if(livro.value_coded=6262,'LIVRO 2','')) livro,
					pagina.value_numeric pagina,
					linha.value_numeric linha,
                    registo_tarv.local_livro_tarv,
                    registo_tarv.location_id
                               
            from
                (   select  p.patient_id,
							e.location_id,
							l.name local_livro_tarv,
							e.encounter_datetime data_inscricao,
							e.encounter_id
					from    patient p
							inner join encounter e on p.patient_id=e.patient_id
							inner join location l on e.location_id=l.location_id
					where 	e.encounter_type=33 and e.voided=0 and p.voided=0 and 
							e.encounter_datetime<=:endDate and e.location_id=:location
                ) registo_tarv
				left join obs livro on livro.encounter_id=registo_tarv.encounter_id and livro.voided=0 and livro.concept_id=6264
				left join obs pagina on pagina.encounter_id=registo_tarv.encounter_id and pagina.voided=0 and pagina.concept_id=6266
				left join obs linha on linha.encounter_id=registo_tarv.encounter_id and linha.voided=0 and linha.concept_id=6268
        ) tarv on inscricao.patient_id=tarv.patient_id and inscricao.location_id=tarv.location_id
		
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
	) ultimo on inscricao.patient_id=ultimo.patient_id
		
		left join
		(
			select 	pg.patient_id,date_enrolled
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id=2 and location_id=:location
		) inscrito_tratamento on inscrito_tratamento.patient_id=inscricao.patient_id
		
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
	) saida_tarv on inscricao.patient_id=saida_tarv.patient_id	
	
	left join 
		(	select patient_id,min(data_primeiro_cd4) data_primeiro_cd4,max(value_numeric) value_numeric
			from	
				(	select 	e.patient_id,
							min(o.obs_datetime) data_primeiro_cd4
					from 	encounter e
							inner join obs o on e.encounter_id=o.encounter_id
					where 	e.encounter_type=13 and e.voided=0 and
							o.voided=0 and o.concept_id=5497 and e.encounter_datetime <=:endDate and e.location_id=:location
					group by e.patient_id
				) primeiro_cd4
				inner join obs o on o.person_id=primeiro_cd4.patient_id and o.obs_datetime=primeiro_cd4.data_primeiro_cd4
			where o.concept_id=5497 and o.voided=0
			group by patient_id
		) cd4 on cd4.patient_id=inscricao.patient_id
		
		left join
		(	select 	o.person_id patient_id,o.obs_datetime data_estadio,
					case o.value_coded
					when 1204 then 'I'
					when 1205 then 'II'
					when 1206 then 'III'
					when 1207 then 'IV'
					else 'OUTRO' end as valor_estadio
			from 	obs o,				
					(	select 	p.patient_id,min(encounter_datetime) as encounter_datetime
						from 	patient p
								inner join encounter e on p.patient_id=e.patient_id
								inner join obs o on o.encounter_id=e.encounter_id
						where 	encounter_type in (6,9) and e.voided=0 and
								encounter_datetime <=:endDate and e.location_id=:location
								and p.voided=0 and o.voided=0 and o.concept_id=5356
						group by patient_id
					) d
			where 	o.person_id=d.patient_id and o.obs_datetime=d.encounter_datetime and o.voided=0 and 
					o.concept_id=5356 and o.location_id=:location and o.value_coded in (1204,1205,1206,1207)
		)estadio on estadio.patient_id=inscricao.patient_id
		
		left join
		(
			select 	pg.patient_id,date_enrolled
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id=5 and location_id=:location
		) inscrito_tuberculose on inscrito_tuberculose.patient_id=inscricao.patient_id
		
		left join
		(
			select 	pg.patient_id,date_enrolled
			from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
			where 	pg.voided=0 and p.voided=0 and program_id=8 and location_id=:location
		) inscrito_ptv on inscrito_ptv.patient_id=inscricao.patient_im_eriodo