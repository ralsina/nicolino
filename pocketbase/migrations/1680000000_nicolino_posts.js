/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "id": "pbc_nicolino_posts",
    "name": "posts",
    "type": "base",
    "fields": [
      {
        "system": false,
        "id": "field_title",
        "name": "title",
        "type": "text",
        "required": true,
        "presentable": true
      },
      {
        "system": false,
        "id": "field_content",
        "name": "content",
        "type": "editor",
        "required": true
      },
      {
        "system": false,
        "id": "field_published",
        "name": "published",
        "type": "autodate",
        "presentable": true,
        "onCreate": true,
        "onUpdate": false
      },
      {
        "system": false,
        "id": "field_tags",
        "name": "tags",
        "type": "text",
        "presentable": false
      },
      {
        "system": false,
        "id": "field_slug",
        "name": "slug",
        "type": "text",
        "presentable": false
      },
      {
        "system": false,
        "id": "field_excerpt",
        "name": "excerpt",
        "type": "editor"
      },
      {
        "system": false,
        "id": "field_featured_image",
        "name": "featured_image",
        "type": "file",
        "presentable": false
      }
    ]
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("posts");

  return app.delete(collection);
});
