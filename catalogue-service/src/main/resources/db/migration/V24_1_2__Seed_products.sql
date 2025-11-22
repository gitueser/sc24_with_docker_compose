insert into catalogue.t_product (c_title, c_details)
select 'Телевизор LG', 'Большой телевизор для гостиной'
where not exists (
    select 1 from catalogue.t_product where c_title = 'Телевизор LG'
);

insert into catalogue.t_product (c_title, c_details)
select 'Холодильник Samsung', 'Двухкамерный холодильник для семьи'
where not exists (
    select 1 from catalogue.t_product where c_title = 'Холодильник Samsung'
);

insert into catalogue.t_product (c_title, c_details)
select 'Ноутбук Lenovo', 'Рабочий ноутбук для разработки'
where not exists (
    select 1 from catalogue.t_product where c_title = 'Ноутбук Lenovo'
);

insert into catalogue.t_product (c_title, c_details)
select 'Смартфон Xiaomi', 'Бюджетный, но мощный смартфон'
where not exists (
    select 1 from catalogue.t_product where c_title = 'Смартфон Xiaomi'
);

insert into catalogue.t_product (c_title, c_details)
select 'Пылесос Dyson', 'Мощный пылесос для уборки дома'
where not exists (
    select 1 from catalogue.t_product where c_title = 'Пылесос Dyson'
);
