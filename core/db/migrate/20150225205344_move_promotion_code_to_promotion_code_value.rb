class MovePromotionCodeToPromotionCodeValue < ActiveRecord::Migration
  def change
    say_with_time 'generating spree_promotion_codes' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        insert into spree_promotion_codes
          (promotion_id, value, usage_limit, created_at, updated_at)
        select
          p.id,
          p.code,
          p.usage_limit,
          '#{Time.now.to_s(:db)}',
          '#{Time.now.to_s(:db)}'
        from spree_promotions p
        left join spree_promotion_codes c
          on c.promotion_id = p.id
        where (p.code is not null and p.code <> '') -- promotion has a code
          and c.id is null -- a promotion_code hasn't already been created
      SQL
    end
 
    too_many_codes_query = <<-SQL
      select 1 as one
      from spree_promotion_codes
      group by promotion_id
      having count(0) > 1 limit 1
    SQL
    if Spree::Promotion.connection.select_one(too_many_codes_query)
      raise "Error: You have promotions with multiple promo codes. The
             migration code will not work correctly".squish
    end
 
    say_with_time 'linking order promotions' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        update spree_orders_promotions op
        set promotion_code_id = c.id
        from spree_promotions p
        inner join spree_promotion_codes c
          on c.promotion_id = p.id
        where op.promotion_id = p.id
          and op.promotion_code_id is null
      SQL
    end
 
    say_with_time 'linking adjustments' do
      Spree::Promotion.connection.execute(<<-SQL.strip_heredoc)
        update spree_adjustments a
        set promotion_code_id = c.id
        from spree_promotion_actions pa
        inner join spree_promotions p
          on p.id = pa.promotion_id
        inner join spree_promotion_codes c
          on c.promotion_id = p.id
        where a.source_type = 'Spree::PromotionAction'
          and a.source_id = pa.id
          and a.promotion_code_id is null
      SQL
    end
  end
end
