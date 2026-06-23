# Пайплайн для домашнего задания 1 по Hi-C

- `run_hic_pipeline.sh` - пайплайн

## 1. Что делает `run_hic_pipeline.sh`

**Выполняется один раз для всех образцов** (так как референс и Juicer общие):

1. `prepare_reference` — скачивает T2T-CHM13v2.0, распаковывает, переименовывает
   хромосомы (если у вас уже есть `scripts/rename_chroms_t2t.py`, в пайплайне он не пересоздается), индексирует `bwa`, считает `chrom.sizes`.
2. `install_juicer` — клонирует версию Juicer
3. `prepare_restriction_sites` — генерирует файл сайтов `DpnII`.

**Выполняется для каждого образца** (`MoPh7`, `MoPh11`, `MoPh14`, `MoPh15`):

4. `download_sample` — скачивает R1/R2 с сервера.
5. `run_fastqc_for_sample` — FastQC по сырым ридам.
6. `run_cutadapt_for_sample` — обрезка адаптеров/качества
7. `prepare_juicer_dir_for_sample` — создает `data/juicer/<sample>/fastq/` с
   симлинками на обрезанные риды.
8. `run_juicer_for_sample` — запускает `juicer.sh` с ферментом `DpnII`.
9. `finalize_sample` — копирует `inter_30.hic` в `results/hic/<sample>.inter_30.hic`.

Каждый шаг проверяет, не выполнен ли он уже (файл существует и не пустой), и
пропускает себя, если да.

## 2. Как запустить

Из директории практики (там, где `data/`, `results/`, `scripts/`, `tools/`):

```bash
conda activate hic_practice

chmod +x run_hic_pipeline.sh validate_pipeline.sh

# запуск всех 4 образцов
./run_hic_pipeline.sh
```

## Итоговая структура результатов

После успешного запуска получаются файлы:

```text
results/hic/MoPh7.inter_30.hic
results/hic/MoPh11.inter_30.hic
results/hic/MoPh14.inter_30.hic
results/hic/MoPh15.inter_30.hic
```

и для каждого образца — лог `results/cutadapt/<sample>.cutadapt.log`,
отчеты FastQC в `results/fastqc_raw/`, и полная рабочая директория Juicer в
`data/juicer/<sample>/`
