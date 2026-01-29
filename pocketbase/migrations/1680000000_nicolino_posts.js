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
        "type": "date",
        "presentable": true
      },
      {
        "system": false,
        "id": "field_status",
        "name": "status",
        "type": "select",
        "required": true,
        "options": {
          "values": ["draft", "published"],
          "maxSelect": 1,
          "default": "draft"
        }
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
        "pattern": "^[a-z0-9-]+$"
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
