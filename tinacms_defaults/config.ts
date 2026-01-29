import { defineConfig } from "tinacms";

const branch =
  process.env.GITHUB_BRANCH ||
  process.env.VERCEL_GIT_COMMIT_REF ||
  process.env.HEAD ||
  "main";

// Shortcode templates for Nicolino
const shortcodeTemplates = [
  // Self-closing shortcodes ({{< ... >}})
  {
    name: "youtube",
    label: "YouTube",
    match: { start: "{{<", end: "}}>" },
    fields: [
      { name: "id", label: "Video ID", type: "string", required: true },
      { name: "width", label: "Width", type: "string", required: false },
      { name: "height", label: "Height", type: "string", required: false },
    ],
  },
  {
    name: "thumbnail",
    label: "Thumbnail",
    match: { start: "{{<", end: "}}>" },
    fields: [
      { name: "path", label: "Image Path", type: "string", required: true },
      { name: "alt", label: "Alt Text", type: "string", required: false },
      { name: "align", label: "Alignment", type: "string", required: false },
      { name: "linktitle", label: "Link Title", type: "string", required: false },
      { name: "title", label: "Title", type: "string", required: false },
      { name: "imgclass", label: "CSS Class", type: "string", required: false },
    ],
  },
  {
    name: "figure",
    label: "Figure",
    match: { start: "{{<", end: "}}>" },
    fields: [
      { name: "src", label: "Source", type: "string", required: true },
      { name: "link", label: "Link", type: "string", required: true },
      { name: "caption", label: "Caption", type: "string", required: true },
    ],
  },
  {
    name: "gallery",
    label: "Gallery",
    match: { start: "{{<", end: "}}>" },
    fields: [
      { name: "name", label: "Gallery Name", type: "string", required: true },
      { name: "css_class", label: "CSS Class", type: "string", required: false },
    ],
  },
  // Block shortcodes with content ({{% ... %}})
  {
    name: "raw",
    label: "Raw Content",
    match: { start: "{{%", end: "%}}" },
    fields: [
      {
        name: "children",
        label: "Content",
        type: "string",
        required: true,
        ui: { component: "textarea" },
      },
    ],
  },
  {
    name: "shell",
    label: "Shell Command",
    match: { start: "{{%", end: "%}}" },
    fields: [
      { name: "command", label: "Command", type: "string", required: true },
      {
        name: "children",
        label: "Content",
        type: "rich-text",
        required: false,
      },
    ],
  },
  {
    name: "tag",
    label: "HTML Tag",
    match: { start: "{{%", end: "%}}" },
    fields: [
      { name: "tag", label: "Tag", type: "string", required: true },
      { name: "class", label: "CSS Class", type: "string", required: false },
      { name: "id", label: "ID", type: "string", required: false },
      { name: "role", label: "ARIA Role", type: "string", required: false },
      {
        name: "children",
        label: "Content",
        type: "rich-text",
        required: false,
      },
    ],
  },
  {
    name: "card",
    label: "Card",
    match: { start: "{{%", end: "%}}" },
    fields: [
      { name: "class", label: "CSS Class", type: "string", required: false },
      { name: "id", label: "ID", type: "string", required: false },
      {
        name: "children",
        label: "Content",
        type: "rich-text",
        required: false,
      },
    ],
  },
  {
    name: "admonition",
    label: "Admonition",
    match: { start: "{{%", end: "%}}" },
    fields: [
      {
        name: "type",
        label: "Type",
        type: "string",
        required: true,
        ui: {
          component: "select",
          options: ["note", "warning", "tip", "danger", "info", "success"],
        },
      },
      { name: "title", label: "Title", type: "string", required: false },
      {
        name: "children",
        label: "Content",
        type: "rich-text",
        required: false,
      },
    ],
  },
  {
    name: "hero",
    label: "Hero",
    match: { start: "{{%", end: "%}}" },
    fields: [
      {
        name: "tag",
        label: "HTML Tag",
        type: "string",
        required: false,
        defaultValue: "section",
      },
      { name: "id", label: "ID", type: "string", required: false },
      {
        name: "children",
        label: "Content",
        type: "rich-text",
        required: false,
      },
    ],
  },
];

export default defineConfig({
  branch,

  clientId: process.env.NEXT_PUBLIC_TINA_CLIENT_ID,
  token: process.env.TINA_TOKEN,

  build: {
    outputFolder: "admin",
    publicFolder: "assets",
  },
  media: {
    tina: {
      publicFolder: "content",
      mediaRoot: "media",
      static: false,
    },
  },
  schema: {
    collections: [
      {
        name: "post",
        label: "Posts",
        path: "content/posts",
        format: "md",
        fields: [
          {
            type: "string",
            name: "title",
            label: "Title",
            isTitle: true,
            required: true,
          },
          {
            type: "datetime",
            name: "date",
            label: "Date",
            required: true,
          },
          {
            type: "string",
            name: "tags",
            label: "Tags",
          },
          {
            type: "rich-text",
            name: "body",
            label: "Body",
            isBody: true,
            templates: shortcodeTemplates,
          },
        ],
      },
      {
        name: "page",
        label: "Pages",
        path: "content",
        format: "md",
        match: {
          exclude: ["posts/**", "galleries/**", "books/**", "listings/**"],
        },
        fields: [
          {
            type: "string",
            name: "title",
            label: "Title",
            isTitle: true,
            required: true,
          },
          {
            type: "rich-text",
            name: "body",
            label: "Body",
            isBody: true,
            templates: shortcodeTemplates,
          },
        ],
      },
    ],
  },
});
