SET SERVEROUTPUT ON;
VARIABLE b_fecha varchar2(6);
EXEC :b_fecha:= '202106';
VARIABLE  b_pct1 number;
EXEC :b_pct1 := 0.35;
VARIABLE  b_pct2 number;
EXEC :b_pct2 := 0.30;
VARIABLE  b_pct3 number;
EXEC :b_pct3 := 0.25;
VARIABLE  b_pct4 number;
EXEC :b_pct4 := 0.20;
VARIABLE  b_pct5 number;
EXEC :b_pct5 := 0.15;
DECLARE
    v_minid   number;
    v_maxid   number;
    v_idemp number;
    v_runemp empleado.rut_empleado%TYPE;
    v_nom empleado.nombres%TYPE;
    v_categorizacion empleado.id_categorizacion%TYPE;
    v_idequipo empleado.id_equipo%TYPE;
    v_nro_ventas number;
    v_ventas_netas_mes number;
    v_asignacion_vtas number;
    v_pctcat  number;
    v_incentivo_categorizacion number;
    v_pctequipo number;
    v_nomequipo VARCHAR2(10);
   v_bono_equipo number;
   v_anti number;
   v_asignacion_antig number;
   v_descuentos number;
   v_total_mes number;
   v_pctcom number;
   v_comision_ventas number;
BEGIN
    select min(id_empleado), max(id_empleado) 
    into v_minid, v_maxid
    from empleado;
    
    while v_minid <= v_maxid
    LOOP
        --lista de los empleados
        select id_empleado, rut_empleado, apellidos || ' ' || nombres, id_categorizacion, id_equipo
        into v_idemp, v_runemp, v_nom, v_categorizacion, v_idequipo
        from empleado
        where id_empleado = v_minid;
        --DBMS_OUTPUT.put_line('lista de los empleados:' || id_empleado, rut_empleado, apellidos || ' ' || nombres, id_categorizacion, id_equipo );
        
        ---A  Detalle Ventas de los empleados
        select count(*), nvl(sum(db.cantidad*p.precio),0)
        into v_nro_ventas,v_ventas_netas_mes
        from boleta b inner join detalleboleta db
        on b.id_boleta = db.id_boleta
        inner join producto p 
        on p.id_producto = db.id_producto
            where to_char(b.fecha_boleta,'YYYYMM') =: b_fecha
            and b.id_empleado = v_minid;
        DBMS_OUTPUT.put_line('A ----->Detalle Ventas de los empleados:' || v_nro_ventas ||'  ' || v_ventas_netas_mes);
       
       
         --- B asignación especial
        if (v_nro_ventas > 10 ) then 
            v_asignacion_vtas := v_ventas_netas_mes * :b_pct1;
        elsif(v_nro_ventas between 9 and 10) then
            v_asignacion_vtas := v_ventas_netas_mes * :b_pct2;
        elsif(v_nro_ventas between 6 and 8) then
            v_asignacion_vtas := v_ventas_netas_mes * :b_pct3;
        elsif(v_nro_ventas between 3 and 5) then
            v_asignacion_vtas := v_ventas_netas_mes * :b_pct4;
        elsif(v_nro_ventas between 1 and 2) then
            v_asignacion_vtas := v_ventas_netas_mes * :b_pct5;
        end if;
        v_asignacion_vtas := round(v_asignacion_vtas);
         DBMS_OUTPUT.put_line('B ----->asignación especial:' || v_asignacion_vtas);
       
       --C Incentivo por categorización
       select porcentaje / 100
       into v_pctcat
       from categorizacion
       where id_categorizacion = v_categorizacion;
       v_incentivo_categorizacion := round(v_ventas_netas_mes * v_pctcat);
       DBMS_OUTPUT.put_line('C ----->Incentivo por categorización:' || v_incentivo_categorizacion);
    
        --D bono por grupo
       select (porc/100), nom_equipo
       into v_pctequipo,  v_nomequipo
       from equipo
       where id_equipo  = v_idequipo;
       v_bono_equipo := round(v_ventas_netas_mes * v_pctequipo);
       DBMS_OUTPUT.put_line('D ----->Incentivo por equipo:' || v_pctequipo);
    
        ---E asignacion especial
         select extract (year from sysdate) - extract(year from FECCONTRATO)
         into v_anti
         from empleado
         where id_empleado = v_minid;
         v_asignacion_antig :=  round(case
                                        when v_anti > 15 then v_ventas_netas_mes * 0.27
                                        when v_anti between 6 and 15 then v_ventas_netas_mes * 0.14
                                        when v_anti between 3 and 7 then v_ventas_netas_mes * 0.04
                                        else 0
                                    end);
         DBMS_OUTPUT.put_line('E ----->asignacion especialo:' || v_asignacion_antig);
         -- F  Descuentos mes
         select monto
         into v_descuentos
         from descuento
         where id_empleado = v_minid
         and mes = substr(:b_fecha,-2)-1;
         DBMS_OUTPUT.put_line('E ----->Descuento mes:' || v_descuentos);
         
         -- G Total de las ventas mensuales 
         -- Las variables definidas abajo, corresponden a los resultados de 
         -- las letras A + B + C + D + E - F
          v_total_mes := (v_ventas_netas_mes + v_asignacion_vtas  + v_incentivo_categorizacion + v_bono_equipo + v_asignacion_antig- v_descuentos);
          DBMS_OUTPUT.put_line('G ----->Total de las ventas mensuales :' || v_total_mes);
         
         -- H  Comisiones mensuales
         select comision / 100
        into v_pctcom
         from comisionempleado
         where v_total_mes between ventaminima and ventamaxima;
         v_comision_ventas := round(v_total_mes * v_pctcom);
         DBMS_OUTPUT.put_line('H ----->Comisiones mensuales :' || v_comision_ventas);
    
    
    ----------Insercion datos.
    insert into detalle_venta_empleado values (substr(:b_fecha,1,4),substr(:b_fecha,-2), v_idemp, v_nom,v_nomequipo,v_nro_ventas,v_ventas_netas_mes,v_bono_equipo,v_incentivo_categorizacion,v_asignacion_vtas,v_asignacion_antig,v_descuentos,v_total_mes);
   
   insert into comision_venta_empleado values(substr(:b_fecha,1,4),substr(:b_fecha,-2),v_idemp,v_total_mes,v_comision_ventas); 
    
    v_minid := v_minid + 2;
    END LOOP;
END;
