/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "id": "pbc_nicolino_pages",
    "name": "pages",
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
        "id": "field_slug",
        "name": "slug",
        "type": "text",
        "required": true,
        "unique": true
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
        "id": "field_sort_order",
        "name": "sort_order",
        "type": "number",
        "presentable": false
      }
    ]
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pages");

  return app.delete(collection);
});
