# Nicolino

A performant, tiny, SSG (yeah, sure)

## WARNING

This is a toy. Do not use this for anything important. Yet, maybe.

## What is it tho

It's a SSG, a Static Site Generator. You know, those things where
you write some markdown and end up with a website.

## Why

Because I am learning [Crystal](https://crystal-lang.org) and I know
a lot about SSGs, so it's a nice project.

## Will it be any good

Probably not? I am an old guy and my energy is limited and I don't
**need** this, so I will just keep adding stuff while it's fun.

## What's planned

Nothing is planned, this is strictly a make it up as you go operation.
BUT check out the [TODO list](TODO.md)

## More information

You can consider it a "demo" at <https://nicolino.ralsina.me>

## Building for Release (Static Binaries)

The project uses `libvips` for fast image processing, but libvips cannot be statically linked. To create static binaries, we use the `-Dnovips` flag which falls back to `crimage` (a pure-Crystal image library).

**Important trade-offs:**
- **Non-release builds with crimage are very slow** - image processing will take noticeably longer
- **Release builds with crimage are somewhat faster** - but still slower than libvips
- **Static builds require `-Dnovips`** - otherwise linking will fail due to missing libvips static libraries

For development use, build without `-Dnovips` for fast image processing with libvips. For release/static builds, use `-Dnovips` and accept the performance trade-off.
