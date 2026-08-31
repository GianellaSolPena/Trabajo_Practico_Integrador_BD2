--
-- PostgreSQL database dump
--

-- Dumped from database version 16.6 (Postgres.app)
-- Dumped by pg_dump version 17.2 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: estado_pedido; Type: TYPE; Schema: public; Owner: gianellapena
--

CREATE TYPE public.estado_pedido AS ENUM (
    'PENDIENTE',
    'CONFIRMADO',
    'TERMINADO',
    'CANCELADO'
);


ALTER TYPE public.estado_pedido OWNER TO gianellapena;

--
-- Name: forma_pago; Type: TYPE; Schema: public; Owner: gianellapena
--

CREATE TYPE public.forma_pago AS ENUM (
    'EFECTIVO',
    'CREDITO',
    'DEBITO',
    'TRANSFERENCIA',
    'TARJETA'
);


ALTER TYPE public.forma_pago OWNER TO gianellapena;

--
-- Name: fn_completar_subtotal(); Type: FUNCTION; Schema: public; Owner: gianellapena
--

CREATE FUNCTION public.fn_completar_subtotal() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.precio_unitario := (
        SELECT precio FROM producto WHERE id_producto = NEW.producto_id
    );
    NEW.subtotal := NEW.cantidad * NEW.precio_unitario;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_completar_subtotal() OWNER TO gianellapena;

--
-- Name: fn_validar_estado_pedido(); Type: FUNCTION; Schema: public; Owner: gianellapena
--

CREATE FUNCTION public.fn_validar_estado_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF OLD.estado IS DISTINCT FROM NEW.estado
       AND NOT (
            (OLD.estado = 'PENDIENTE'  AND NEW.estado = 'CONFIRMADO') OR
            (OLD.estado = 'PENDIENTE'  AND NEW.estado = 'CANCELADO')  OR
            (OLD.estado = 'CONFIRMADO' AND NEW.estado = 'TERMINADO')
       )
    THEN
        RAISE EXCEPTION 'chk_pedido_estado: transición de estado inválida de % a %',
            OLD.estado, NEW.estado;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_estado_pedido() OWNER TO gianellapena;

--
-- Name: fn_validar_fecha_pedido(); Type: FUNCTION; Schema: public; Owner: gianellapena
--

CREATE FUNCTION public.fn_validar_fecha_pedido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.fecha::date < CURRENT_DATE THEN
        RAISE EXCEPTION 'chk_pedido_fecha_no_pasada: la fecha del pedido (%) no puede ser anterior a la fecha actual (%)',
            NEW.fecha, CURRENT_DATE;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.fn_validar_fecha_pedido() OWNER TO gianellapena;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categoria; Type: TABLE; Schema: public; Owner: gianellapena
--

CREATE TABLE public.categoria (
    id_categoria bigint NOT NULL,
    nombre character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone
);


ALTER TABLE public.categoria OWNER TO gianellapena;

--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE; Schema: public; Owner: gianellapena
--

ALTER TABLE public.categoria ALTER COLUMN id_categoria ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.categoria_id_categoria_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: detalle_pedido; Type: TABLE; Schema: public; Owner: gianellapena
--

CREATE TABLE public.detalle_pedido (
    pedido_id bigint NOT NULL,
    producto_id bigint NOT NULL,
    cantidad integer NOT NULL,
    precio_unitario numeric(10,2) NOT NULL,
    subtotal numeric(10,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    CONSTRAINT detalle_pedido_cantidad_check CHECK ((cantidad > 0))
);


ALTER TABLE public.detalle_pedido OWNER TO gianellapena;

--
-- Name: pedido; Type: TABLE; Schema: public; Owner: gianellapena
--

CREATE TABLE public.pedido (
    id_pedido bigint NOT NULL,
    fecha timestamp with time zone DEFAULT now() NOT NULL,
    estado public.estado_pedido DEFAULT 'PENDIENTE'::public.estado_pedido NOT NULL,
    forma_pago public.forma_pago DEFAULT 'EFECTIVO'::public.forma_pago NOT NULL,
    usuario_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone
);


ALTER TABLE public.pedido OWNER TO gianellapena;

--
-- Name: pedido_id_pedido_seq; Type: SEQUENCE; Schema: public; Owner: gianellapena
--

ALTER TABLE public.pedido ALTER COLUMN id_pedido ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.pedido_id_pedido_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: producto; Type: TABLE; Schema: public; Owner: gianellapena
--

CREATE TABLE public.producto (
    id_producto bigint NOT NULL,
    nombre character varying(100) NOT NULL,
    precio numeric(10,2) NOT NULL,
    descripcion character varying(250),
    stock integer DEFAULT 0 NOT NULL,
    categoria_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    CONSTRAINT chk_producto_precio_positivo CHECK ((precio > (0)::numeric)),
    CONSTRAINT producto_stock_check CHECK ((stock >= 0))
);


ALTER TABLE public.producto OWNER TO gianellapena;

--
-- Name: producto_id_producto_seq; Type: SEQUENCE; Schema: public; Owner: gianellapena
--

ALTER TABLE public.producto ALTER COLUMN id_producto ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.producto_id_producto_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: usuario; Type: TABLE; Schema: public; Owner: gianellapena
--

CREATE TABLE public.usuario (
    id_usuario bigint NOT NULL,
    nombre character varying(50) NOT NULL,
    apellido character varying(50) NOT NULL,
    mail character varying(100) NOT NULL,
    celular character varying(20),
    contrasena character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone,
    deleted_at timestamp with time zone,
    CONSTRAINT chk_mail_formato CHECK (((mail)::text ~~ '%@%.%'::text))
);


ALTER TABLE public.usuario OWNER TO gianellapena;

--
-- Name: usuario_id_usuario_seq; Type: SEQUENCE; Schema: public; Owner: gianellapena
--

ALTER TABLE public.usuario ALTER COLUMN id_usuario ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.usuario_id_usuario_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: categoria; Type: TABLE DATA; Schema: public; Owner: gianellapena
--

COPY public.categoria (id_categoria, nombre, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: detalle_pedido; Type: TABLE DATA; Schema: public; Owner: gianellapena
--

COPY public.detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: pedido; Type: TABLE DATA; Schema: public; Owner: gianellapena
--

COPY public.pedido (id_pedido, fecha, estado, forma_pago, usuario_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: producto; Type: TABLE DATA; Schema: public; Owner: gianellapena
--

COPY public.producto (id_producto, nombre, precio, descripcion, stock, categoria_id, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: usuario; Type: TABLE DATA; Schema: public; Owner: gianellapena
--

COPY public.usuario (id_usuario, nombre, apellido, mail, celular, contrasena, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Name: categoria_id_categoria_seq; Type: SEQUENCE SET; Schema: public; Owner: gianellapena
--

SELECT pg_catalog.setval('public.categoria_id_categoria_seq', 5, true);


--
-- Name: pedido_id_pedido_seq; Type: SEQUENCE SET; Schema: public; Owner: gianellapena
--

SELECT pg_catalog.setval('public.pedido_id_pedido_seq', 7, true);


--
-- Name: producto_id_producto_seq; Type: SEQUENCE SET; Schema: public; Owner: gianellapena
--

SELECT pg_catalog.setval('public.producto_id_producto_seq', 4, true);


--
-- Name: usuario_id_usuario_seq; Type: SEQUENCE SET; Schema: public; Owner: gianellapena
--

SELECT pg_catalog.setval('public.usuario_id_usuario_seq', 10, true);


--
-- Name: categoria categoria_pkey; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id_categoria);


--
-- Name: usuario chk_username_unico; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT chk_username_unico UNIQUE (mail);


--
-- Name: detalle_pedido detalle_pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_pkey PRIMARY KEY (pedido_id, producto_id);


--
-- Name: pedido pedido_pkey; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_pkey PRIMARY KEY (id_pedido);


--
-- Name: producto producto_pkey; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id_producto);


--
-- Name: usuario usuario_pkey; Type: CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id_usuario);


--
-- Name: idx_pedido_usuario; Type: INDEX; Schema: public; Owner: gianellapena
--

CREATE INDEX idx_pedido_usuario ON public.pedido USING btree (usuario_id);


--
-- Name: idx_producto_categoria; Type: INDEX; Schema: public; Owner: gianellapena
--

CREATE INDEX idx_producto_categoria ON public.producto USING btree (categoria_id);


--
-- Name: pedido trg_pedido_fecha_no_pasada; Type: TRIGGER; Schema: public; Owner: gianellapena
--

CREATE TRIGGER trg_pedido_fecha_no_pasada BEFORE INSERT OR UPDATE ON public.pedido FOR EACH ROW EXECUTE FUNCTION public.fn_validar_fecha_pedido();


--
-- Name: detalle_pedido trg_subtotal; Type: TRIGGER; Schema: public; Owner: gianellapena
--

CREATE TRIGGER trg_subtotal BEFORE INSERT OR UPDATE ON public.detalle_pedido FOR EACH ROW EXECUTE FUNCTION public.fn_completar_subtotal();


--
-- Name: pedido trg_validar_estado_pedido; Type: TRIGGER; Schema: public; Owner: gianellapena
--

CREATE TRIGGER trg_validar_estado_pedido BEFORE UPDATE OF estado ON public.pedido FOR EACH ROW EXECUTE FUNCTION public.fn_validar_estado_pedido();


--
-- Name: detalle_pedido detalle_pedido_pedido_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedido(id_pedido) ON DELETE CASCADE;


--
-- Name: detalle_pedido detalle_pedido_producto_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.detalle_pedido
    ADD CONSTRAINT detalle_pedido_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES public.producto(id_producto) ON DELETE RESTRICT;


--
-- Name: pedido pedido_usuario_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.pedido
    ADD CONSTRAINT pedido_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.usuario(id_usuario) ON DELETE RESTRICT;


--
-- Name: producto producto_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: gianellapena
--

ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categoria(id_categoria) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--

