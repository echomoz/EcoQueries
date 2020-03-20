-- SQL desenhado por Eurico Jose, FGH
-- Modificado por Horácio Mondlane, FHI360
-- Modificado por Xavier Nhagumbe Abt Associates Inc.
-- Encontrar os respectivos pacientes para cada estado
select *
from
(select 	pid.identifier as nid,
		concat(ifnull(pn.given_name,''),' ',ifnull(pn.middle_name,''),' ',ifnull(pn.family_name,'')) nome,
		pe.gender,
		round(datediff(:endDate,pe.birthdate)/360) idade,
		pad3.county_district as 'Distrito',
			pad3.address2 as 'PAdministrativo',
			pad3.address6 as 'Localidade',
			pad3.address5 as 'Bairro',
			pad3.address1 as 'PontoReferencia',
			pa.value as contacto,
			pessoa_referencia.value_text as pessoa,
		coorte6meses_final.data_inicio,
		regime.ultimo_regime,
		ultimacv.data_carga,
		ultimacv.valor_carga,
		proveniencia.referencia,
		coorte6meses_final.data_fila,
		coorte6meses_final.data_proximo_lev,
		coorte6meses_final.data_seguimento,
		coorte6meses_final.data_proximo_seguimento,
		coorte6meses_final.patient_id
from
-- 1. Aqui determina-se a data que será usada para ser comparada com a data em que o paciente completa 6 meses de tarv
-- 1.1 Se o paciente não tiver data do proximo levantamento e tiver a data da proxima consulta estimada, esta será usada
-- 1.2 Se o paciente não tiver data da proxima consulta estimada e tiver a data do proximo levantamento, esta será usada
-- 1.3 Se a data da proxima consulta estimada for maior que a data do proximo levantamento, a data da proxima consulta é usada, caso não será usada a data da proxima consulta
-- 2. Determinacao do estado final
-- 2.1 Se o paciente tiver um estado preenchido (Transferido para, suspenso, abandono, obito) antes dos 6 meses de tarv, este será usado como estado final
-- 2.2 Se o paciente não tiver nenhuma data no ponto 1 (paciente sem nenhum levantamento ou consulta clinica dentro de 6 meses de inicio de TARV) será considerado ABANDONO
-- 2.2 Se a data em que completa 6 meses for maior que a data encontrada em 1 será considerado abandono caso não será activo 
(select   coorte6meses.*,	
	if (estado_id is not null,estado_id,
		if(if(data_proximo_lev is null and data_proximo_seguimento_estimada is not null,data_proximo_seguimento_estimada,
            if(data_proximo_lev is not null and data_proximo_seguimento_estimada is null,data_proximo_lev,
              if(data_proximo_seguimento_estimada>data_proximo_lev,data_proximo_seguimento_estimada,data_proximo_lev))) is null,9,
		if(date(:endDate)>date_add(if(data_proximo_lev is null and data_proximo_seguimento_estimada is not null,data_proximo_seguimento_estimada,
            if(data_proximo_lev is not null and data_proximo_seguimento_estimada is null,data_proximo_lev,
              if(data_proximo_seguimento_estimada>data_proximo_lev,data_proximo_seguimento_estimada,data_proximo_lev))), interval 60 day),9,6))) estado_final



from
-- Aqui construimos uma tabela com informacao ultimo fila, seguimento e as datas proximas de fila e seguimento
-- A data do proximo seguimento não é frequentemente preenchida, por via disso temos a data do proximo seguimento calculado,
-- Se paciente não tiver a data do proximo seguimento esta é calculada usando a data de seguimento + 30 dias
(select 	inicio_estado.*,
		obs_fila.value_datetime data_proximo_lev,
		obs_fila.encounter_id encounter_id_fila,
		obs_seguimento.value_datetime data_proximo_seguimento,
		obs_seguimento.encounter_id encounter_id_seg,
    if(data_seguimento is not null and obs_seguimento.value_datetime is null,date_add(data_seguimento, interval 30 day),obs_seguimento.value_datetime) data_proximo_seguimento_estimada
from
-- Aqui construimos uma tabela que tem os campos: data de inicio de tarv do paciente, data que completa 6 meses, data do ultimo estado antes dos 6 meses,
-- data do ultimo levantamento antes dos 6 meses, data da ultima consulta antes dos 6 meses
-- o estado antes do 6 meses tambem está incluido
(select inicio.*,
		max(ps.start_date) data_estado,
			case ps.state
			  when 7 then 'TRANSFERIDO PARA'
			  when 8 then 'SUSPENSO'
			  when 9 then 'ABANDONO'
			  when 10 then 'OBITO'
			end as estado,
			ps.state estado_id,
		max(e.encounter_datetime) data_fila,
		max(e.encounter_datetime) data_seguimento

from
-- A real data de inicio de TARV do paciente é a minima das primeiras ocorrencias dos conceitos de Gestao de TARV, data de inicio de TARV, inscricao no programa de tratamento e fila inicial
-- A partir da data de inicio de TARV é adicionado 6 meses.
-- Ex: se data de inicio for 01.01.2016, adicionar 1 ano o MySQL tira 01.01.2017 menos 1 dia a real data sera 31.12.2016
-- A tabela interna 'inicio' é composta por 3 campos: patient_id, data_inicio, data6meses
(	Select patient_id,min(data_inicio) data_inicio,date_add(min(data_inicio), interval 6 MONTH) data6meses
		from
			(	
				-- leva a primeira ocorrencia do conceito 1255: Gestão de TARV e que a resposta foi 1256: Inicio
				Select 	p.patient_id,min(e.encounter_datetime) data_inicio
				from 	patient p
						inner join encounter e on p.patient_id=e.patient_id
						inner join obs o on o.encounter_id=e.encounter_id
				where 	e.voided=0 and o.voided=0 and p.voided=0 and
						e.encounter_type in (18,6,9) and o.concept_id=1255 and o.value_coded=1256 and
						e.encounter_datetime<=:endDate and e.location_id=:location
				group by p.patient_id

				union
				
				-- leva a primeira ocorrencia do conceito 1190: Data de Inicio de TARV
				Select 	p.patient_id,min(value_datetime) data_inicio
				from 	patient p
						inner join encounter e on p.patient_id=e.patient_id
						inner join obs o on e.encounter_id=o.encounter_id
				where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (18,6,9) and
						o.concept_id=1190 and o.value_datetime is not null and
						o.value_datetime<=:endDate and e.location_id=:location
				group by p.patient_id

				union

				-- leva a primeira ocorrencia da inscricao do paciente no programa de Tratamento ARV
				select 	pg.patient_id,date_enrolled data_inicio
				from 	patient p inner join patient_program pg on p.patient_id=pg.patient_id
				where 	pg.voided=0 and p.voided=0 and program_id=2 and date_enrolled<=:endDate and pg.location_id=:location

				union
				
				-- Leva a data do primeiro levantamento de ARV para cada paciente: Data do primeiro Fila do paciente
				  SELECT 	e.patient_id, MIN(e.encounter_datetime) AS data_inicio
				  FROM 		patient p
							inner join encounter e on p.patient_id=e.patient_id
				  WHERE		p.voided=0 and e.encounter_type=18 AND e.voided=0 and e.encounter_datetime<=:endDate and e.location_id=:location
				  GROUP BY 	p.patient_id



			) inicio_real
		group by patient_id
)inicio
-- Aqui encontramos os estados paciente até antes dos 6 meses, repare que este estado pode não ser o estado actual
left join
	patient_program pg on inicio.patient_id=pg.patient_id
	and pg.program_id=2
	and pg.location_id=:location
	and pg.voided=0
left join
	patient_state ps on pg.patient_program_id=ps.patient_program_id
	and ps.voided=0
	and ps.state in (7,8,9,10)
	and ps.start_date between inicio.data_inicio and :endDate
	and (ps.end_date is null or (ps.end_date is not null and ps.end_date) > :endDate)
-- Aqui encontramos os levantamentos de ARV efectuados do paciente antes dos 6 meses de TARV
left join
	encounter e on e.patient_id=inicio.patient_id
	and e.encounter_type=18
	and e.encounter_datetime between inicio.data_inicio and :endDate
	and e.voided=0
	and e.location_id=:location
-- Aqui encontramos as consultas efectuadas do paciente antes dos 6 meses de TARV
left join
	encounter e1 on e1.patient_id=inicio.patient_id
	and e1.encounter_type in (6,9)
	and e1.encounter_datetime between inicio.data_inicio and :endDate
	and e1.voided=0
	and e1.location_id=:location
-- Aqui filtramos os pacientes que somente iniciaram TARV no nosso periodo de interesse
where data_inicio<=:endDate
group by patient_id
) inicio_estado
-- Aqui encontramos a data do proximo levantamento marcado no ultimo levantamento de ARV antes dos 6 meses
left join
	obs obs_fila on obs_fila.person_id=inicio_estado.patient_id
	and obs_fila.voided=0
	and obs_fila.obs_datetime=inicio_estado.data_fila
	and obs_fila.concept_id=5096
	and obs_fila.location_id=:location
-- Aqui encontramos a data da proxima consulta marcada na ultima consulta antes dos 6 meses
left join
	obs obs_seguimento on obs_seguimento.person_id=inicio_estado.patient_id
	and obs_seguimento.voided=0
	and obs_seguimento.obs_datetime=inicio_estado.data_seguimento
	and obs_seguimento.concept_id=1410
	and obs_seguimento.location_id=:location
) coorte6meses
group by patient_id
) coorte6meses_final
inner join person pe on pe.person_id=coorte6meses_final.patient_id
left join 
(	Select ultima_carga.*,if(obs.value_numeric<0,'INDETECTAVEL',obs.value_numeric) valor_carga
	from
	(	Select 	p.patient_id,max(o.obs_datetime) data_carga
		from 	patient p
				inner join encounter e on p.patient_id=e.patient_id
				inner join obs o on e.encounter_id=o.encounter_id
		where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (13,6,9) and 
				o.concept_id=856 and o.value_numeric is not null and 
				e.encounter_datetime<=:endDate and e.location_id=:location
		group by p.patient_id
	) ultima_carga
	inner join obs on obs.person_id=ultima_carga.patient_id and obs.obs_datetime=ultima_carga.data_carga
	where 	obs.voided=0 and obs.concept_id=856 and obs.location_id=:location 		
)ultimacv on coorte6meses_final.patient_id=ultimacv.patient_id
left join 
(
	select 	ultimo_lev.patient_id,
			case o.value_coded
				when 1651 then 'AZT+3TC+NVP'
				when 6324 then 'TDF+3TC+EFV'
				when 1703 then 'AZT+3TC+EFV'
				when 6243 then 'TDF+3TC+NVP'
				when 6103 then 'D4T+3TC+LPV/r'
				when 792 then 'D4T+3TC+NVP'
				when 1827 then 'D4T+3TC+EFV'
				when 6102 then 'D4T+3TC+ABC'
				when 6116 then 'AZT+3TC+ABC'
				when 6110 then 'TRIOMUNE BABY'
				when 6108 then 'TDF+3TC+LPV/r(2ª Linha)'
				when 6100 then 'AZT+3TC+LPV/r(2ª Linha)'
				when 6329 then 'TDF+3TC+RAL+DRV/r (3ª Linha)'
				when 6330 then 'AZT+3TC+RAL+DRV/r (3ª Linha)'
				when 6105 then 'ABC+3TC+NVP'
				when 6102 then 'D4T+3TC+ABC'
				when 6325 then 'D4T+3TC+ABC+LPV/r (2ª Linha)'
				when 6326 then 'AZT+3TC+ABC+LPV/r (2ª Linha)'
				when 6327 then 'D4T+3TC+ABC+EFV (2ª Linha)'
				when 6328 then 'AZT+3TC+ABC+EFV (2ª Linha)'
				when 6109 then 'AZT+DDI+LPV/r (2ª Linha)'
				when 6329 then 'TDF+3TC+RAL+DRV/r (3ª Linha)'
			else 'OUTRO' end as ultimo_regime,
			ultimo_lev.encounter_datetime data_regime
	from 	obs o,				
			(	select p.patient_id,max(encounter_datetime) as encounter_datetime
				from 	patient p
						inner join encounter e on p.patient_id=e.patient_id								
				where 	encounter_type=18 and e.voided=0 and
						encounter_datetime <=:endDate and e.location_id=:location and p.voided=0
				group by patient_id
			) ultimo_lev
	where 	o.person_id=ultimo_lev.patient_id and o.obs_datetime=ultimo_lev.encounter_datetime and o.voided=0 and 
			o.concept_id=1088 and o.location_id=:location
) regime on regime.patient_id=coorte6meses_final.patient_id
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
		)proveniencia on proveniencia.patient_id=coorte6meses_final.patient_id
left join 
(	select pid1.*
	from patient_identifier pid1
	inner join 
		(
			select patient_id,min(patient_identifier_id) id 
			from patient_identifier
			where voided=0
			group by patient_id
		) pid2
	where pid1.patient_id=pid2.patient_id and pid1.patient_identifier_id=pid2.id
) pid on pid.patient_id=coorte6meses_final.patient_id
left join 
(	select pn1.*
	from person_name pn1
	inner join 
		(
			select person_id,min(person_name_id) id 
			from person_name
			where voided=0
			group by person_id
		) pn2
	where pn1.person_id=pn2.person_id and pn1.person_name_id=pn2.id
) pn on pn.person_id=coorte6meses_final.patient_id

left join person_attribute pa on pa.person_id=coorte6meses_final.patient_id and pa.person_attribute_type_id=9

left join 
		(	select patient_id,o.value_text
			from encounter e
			inner join obs o on o.encounter_id=e.encounter_id			
			where encounter_type in (5,7) and o.concept_id=1611 and o.voided=0 and e.location_id=:location 
			group by patient_id
		) pessoa_referencia on pessoa_referencia.patient_id=coorte6meses_final.patient_id
left join 
			(	select pad1.*
				from person_address pad1
				inner join 
				(
					select person_id,min(person_address_id) id 
					from person_address
					where voided=0
					group by person_id
				) pad2
				where pad1.person_id=pad2.person_id and pad1.person_address_id=pad2.id
			) pad3 on pad3.person_id=coorte6meses_final.patient_id	



-- Verificação qual é o estado final
where 	estado_final=6 and 
		coorte6meses_final.patient_id not in 
		(
			Select 	p.patient_id
			from 	patient p 
					inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on e.encounter_id=o.encounter_id
			where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1982 and value_coded=44 and 
					e.encounter_type in (5,6) and e.encounter_datetime between date_add(:endDate, interval -10 month) and :endDate and e.location_id=:location

			union		
					
			Select 	p.patient_id
			from 	patient p inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on e.encounter_id=o.encounter_id
			where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1279 and 
					e.encounter_type in (5,6) and e.encounter_datetime between date_add(:endDate, interval -10 month) and :endDate and e.location_id=:location


			union		
					
			Select 	p.patient_id
			from 	patient p inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on e.encounter_id=o.encounter_id
			where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=1600 and 
					e.encounter_type in (5,6) and e.encounter_datetime between date_add(:endDate, interval -10 month) and :endDate and e.location_id=:location		
					
			union
					
			select 	pp.patient_id
			from 	patient_program pp 
			where 	pp.program_id=8 and pp.voided=0 and 
					pp.date_enrolled between date_add(:endDate, interval -10 month) and :endDate and pp.location_id=:location
					
			union		
					
			Select 	p.patient_id
			from 	patient p inner join encounter e on p.patient_id=e.patient_id
					inner join obs o on e.encounter_id=o.encounter_id
			where 	p.voided=0 and e.voided=0 and o.voided=0 and concept_id=856 and 
					e.encounter_type in (9,6,13) and e.encounter_datetime<=:endDate and e.location_id=:location and 
					p.patient_id not in 
									(	Select ultima_carga.patient_id
										from
										(	Select 	p.patient_id,max(o.obs_datetime) data_carga
											from 	patient p
													inner join encounter e on p.patient_id=e.patient_id
													inner join obs o on e.encounter_id=o.encounter_id
											where 	p.voided=0 and e.voided=0 and o.voided=0 and e.encounter_type in (13,6,9) and 
													o.concept_id=856 and o.value_numeric is not null and 
													e.encounter_datetime<=:endDate and e.location_id=:location
											group by p.patient_id
										) ultima_carga
										inner join obs on obs.person_id=ultima_carga.patient_id and obs.obs_datetime=ultima_carga.data_carga
										where 	obs.voided=0 and obs.concept_id=856 and obs.location_id=:location and obs.value_numeric<1000 and round(datediff(:endDate,ultima_carga.data_carga)/30)>=12		
									)
		) and 
		round(datediff(:endDate,coorte6meses_final.data_inicio)/30)>=6
) elegiveiscv
group by patient_id