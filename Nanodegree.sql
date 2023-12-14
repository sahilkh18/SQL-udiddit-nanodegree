-- users table

CREATE TABLE IF NOT EXISTS "new_users" (
"id" SERIAL PRIMARY KEY,
"username" VARCHAR(25) UNIQUE NOT NULL,	
"last_login" TIMESTAMP WITH TIME ZONE,
CONSTRAINT "no_blank_username" CHECK (LENGTH(TRIM("username"))>0)
);

-- topics table

CREATE TABLE IF NOT EXISTS "new_topics" (
"id" SERIAL,
"topic_name" VARCHAR(30) UNIQUE NOT NULL,	
"topic_desc" VARCHAR(500),
PRIMARY KEY ("id"),
CONSTRAINT "no_blank_topic" CHECK (LENGTH(TRIM("topic_name"))>0)
);

CREATE TABLE IF NOT EXISTS "new_posts" (
"id" SERIAL,
"user_id" INT,
"topic_id" INT,
"post_title" VARCHAR(100) NOT NULL,
"url" VARCHAR,
"post_content" VARCHAR,
"post_dt" TIMESTAMP WITH TIME ZONE,
PRIMARY KEY ("id"),
CONSTRAINT "user_id_fk" FOREIGN KEY ("user_id") REFERENCES "new_users"("id") ON DELETE SET NULL,
CONSTRAINT "topic_id_fk" FOREIGN KEY ("topic_id") REFERENCES "new_topics"("id") ON DELETE CASCADE,
CONSTRAINT "url_post_content_fk" CHECK (("url" IS null AND "post_content" IS NOT null) OR ("url" IS NOT null AND "post_content" IS null)),
CONSTRAINT "no_blank_post" CHECK (LENGTH(TRIM("post_title"))>0)
);



CREATE TABLE IF NOT EXISTS "new_comments" (
"id" SERIAL,
"comment_content" VARCHAR,
"user_id" INT,
"post_id" INT,
"comment_id" INT,
"comment_dt" TIMESTAMP WITH TIME ZONE,
PRIMARY KEY ("id"),
CONSTRAINT "comment_id_fk" FOREIGN KEY ("comment_id") REFERENCES "new_comments"("id") ON DELETE CASCADE,
CONSTRAINT "no_blank_comment" CHECK (LENGTH(TRIM("comment_content"))>0)
);


CREATE TABLE IF NOT EXISTS "new_votes" (
"id" SERIAL PRIMARY KEY,
"post_id" INT,
"user_id" INT,
"vote" SMALLINT,
CONSTRAINT "user_id_fk" FOREIGN KEY ("user_id") REFERENCES "new_users"("id") ON DELETE SET NULL,
CONSTRAINT "post_id_fk" FOREIGN KEY ("post_id") REFERENCES "new_posts"("id") ON DELETE CASCADE,
"vote_value" int CHECK (("vote_value" = 1) OR ("vote_value" = -1)),
CONSTRAINT "unique_vote" UNIQUE ("user_id", "post_id")	
);

CREATE INDEX "users_post" ON "new_posts" ("user_id");
CREATE INDEX "posts_url" ON "new_posts" ("url");
CREATE INDEX "posts_topic" ON "new_posts" ("topic_id");
CREATE INDEX "main_comments" ON "new_comments" ("comment_id");
CREATE INDEX "user_comments" ON "new_comments" ("user_id");
CREATE INDEX "votes_cnt" ON "new_votes" ("vote");


INSERT INTO "new_users" ("username")
SELECT DISTINCT "username" FROM public."bad_comments"
UNION
select "username" FROM public."bad_posts"
UNION
SELECT DISTINCT regexp_split_to_table("upvotes",',') 
FROM public.bad_posts
UNION
SELECT DISTINCT regexp_split_to_table("downvotes",',') 
FROM public.bad_posts
;

select * from "new_users";

INSERT INTO public."new_topics"("topic_name")
SELECT DISTINCT "topic"
FROM public.bad_posts;

INSERT INTO public."new_posts"("post_title", "url", "post_content", "user_id", "topic_id")
SELECT LEFT("bp"."title", 100) AS "title", "bp"."url", "bp"."text_content", "u"."id", "tp"."id"
FROM public."bad_posts" "bp"
JOIN public."new_users" "u"
ON "bp"."username" = u.username
JOIN public.new_topics tp
ON bp.topic = tp.topic_name;

select * from new_posts;

INSERT INTO public.new_comments (user_id, post_id, comment_content)
SELECT np.user_id, u.id, bc.text_content
FROM public.bad_comments bc
JOIN public.new_users u
ON u.username = bc.username
JOIN public.new_posts np
ON np.id = bc.post_id;



drop table if exists test;

create temp table if not exists test as (	
select post_id, username, vote, vote_value from 
select post_id, username, 1 as vote_value from (
select id post_id, username, regexp_split_to_table(upvotes, ',') vote_value
from public.bad_posts) a
union
select post_id, username, -1 as vote_value from (
select id post_id, username, regexp_split_to_table(downvotes, ',') vote_value
from public.bad_posts) b);
	
-- 	select count(*) from test
insert into new_votes (post_id,user_id,vote_value )
select post_id, u.id vote from test a
join public.new_users u on a.username = u.username;

INSERT INTO "new_votes" ("user_id","post_id","vote_value")
SELECT new_users.id AS user_id
,a.id AS post_id
,-1 AS "downvotes"
FROM (
SELECT REGEXP_SPLIT_TO_TABLE("downvotes", ',') AS username
,bad_posts.id
FROM bad_posts
) AS a

JOIN new_users ON new_users.username = a.username
JOIN new_posts ON new_posts.user_id = new_users.id

UNION

SELECT new_users.id AS user_id
,b.id AS post_id
,1 AS "upvotes"

FROM (
SELECT REGEXP_SPLIT_TO_TABLE("upvotes", ',') AS username
,bad_posts.id
FROM bad_posts) AS b

JOIN new_users ON new_users.username = b.username
JOIN new_posts ON new_posts.user_id = new_users.id
on conflict do nothing;




INSERT INTO "new_votes" ("user_id","post_id","vote_value")
SELECT new_users.id AS user_id
,a.id AS post_id
,-1 AS "downvotes"
FROM (
SELECT REGEXP_SPLIT_TO_TABLE("downvotes", ',') AS username
,bad_posts.id
FROM bad_posts
) AS a

JOIN new_users ON new_users.username = a.username
JOIN new_posts ON new_posts.user_id = new_users.id

UNION

SELECT new_users.id AS user_id
,b.id AS post_id
,1 AS "upvotes"

FROM (
SELECT REGEXP_SPLIT_TO_TABLE("upvotes", ',') AS username
,bad_posts.id
FROM bad_posts) AS b

JOIN new_users ON new_users.username = b.username
JOIN new_posts ON new_posts.user_id = new_users.id
on conflict do nothing;

alter table new_votes drop column vote;

select * from new_votes;