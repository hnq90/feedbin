module BatchJobs
  BATCH_SIZE = 1_000
  
  def job_args(total_records)
    batch_count = (total_records.to_f/BATCH_SIZE.to_f).ceil
    jobs = []
    1.upto(batch_count) do |batch|
      jobs.push([batch])
    end
    jobs
  end
  
  def build_ids(batch)
    start = ((batch - 1) * BATCH_SIZE) + 1
    finish = batch * BATCH_SIZE
    (start..finish).to_a
  end
end